import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/workout_log.dart';
import '../../shared/widgets/plate_calculator_widget.dart';

class LoggingScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String category;
  final String note;

  const LoggingScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
    this.note = '',
  });

  @override
  ConsumerState<LoggingScreen> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends ConsumerState<LoggingScreen> {
  WorkoutLog? _lastLog;
  bool _loaded = false;
  bool _saving = false;
  bool _isPR = false;
  // Per-exercise unit override (null = follow global preference).
  String? _unitOverride;
  // Date the session is being logged for (defaults to today).
  DateTime _logDate = DateTime.now();

  final List<_SetEntry> _sets = [];

  String get _unitPrefKey => 'pref_unit_${widget.exerciseId}';

  @override
  void initState() {
    super.initState();
    // Load any per-exercise unit override before first build.
    _unitOverride =
        ref.read(sharedPreferencesProvider).getString(_unitPrefKey);
    _loadData();
  }

  void _setUnitOverride(String unit) {
    setState(() => _unitOverride = unit);
    ref.read(sharedPreferencesProvider).setString(_unitPrefKey, unit);
  }

  Future<void> _pickLogDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _logDate,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Log workout for…',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.accent,
                  onPrimary: Colors.white,
                  surface: AppColors.surface,
                  onSurface: AppColors.textPrimary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _logDate = picked);
    }
  }

  String _logDateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = DateTime(_logDate.year, _logDate.month, _logDate.day);
    final diff = today.difference(picked).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[picked.month - 1]} ${picked.day}';
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() { _loaded = true; _sets.add(_SetEntry(weight: 0, reps: 0)); });
      return;
    }

    final last = await ref
        .read(workoutServiceProvider)
        .getLastLog(uid, widget.exerciseId)
        .catchError((_) => null);

    if (mounted) {
      setState(() {
        _lastLog = last;
        _loaded = true;
        if (_sets.isEmpty) {
          final defaultWeight = last?.sets.isNotEmpty == true ? last!.sets.last.weight : 0.0;
          _sets.add(_SetEntry(weight: defaultWeight, reps: 0));
        }
      });
    }
  }

  void _addSet() {
    setState(() {
      final last = _sets.isNotEmpty ? _sets.last : null;
      _sets.add(_SetEntry(
        weight: last?.weight ?? 0,
        reps: last?.reps ?? 0,
        distance: last?.distance ?? 0,
        durationMinutes: last?.durationMinutes ?? 0,
      ));
    });
  }

  void _removeSet(int index) {
    setState(() => _sets.removeAt(index));
  }

  bool get _isCardio => widget.category == 'cardio';

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final isBodyweight = widget.category == 'bodyweight' || widget.category == 'calisthenics';
    final List<WorkoutSet> validSets;
    if (_isCardio) {
      validSets = _sets
          .where((s) => s.distance > 0 && s.durationMinutes > 0)
          .map((s) => WorkoutSet(
                weight: 0,
                reps: 0,
                distance: s.distance,
                durationMinutes: s.durationMinutes,
              ))
          .toList();
    } else {
      validSets = _sets
          .where((s) => (isBodyweight || s.weight > 0) && s.reps > 0)
          .map((s) => WorkoutSet(weight: isBodyweight ? 0 : s.weight, reps: s.reps))
          .toList();
    }

    if (validSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isCardio
            ? 'Add at least one entry with distance and time.'
            : 'Add at least one set with weight and reps.')),
      );
      return;
    }

    setState(() => _saving = true);

    bool isPR = false;
    try {
      final svc = ref.read(workoutServiceProvider);
      if (!_isCardio) {
        final maxWeight = validSets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);
        isPR = await svc.isPersonalRecord(uid, widget.exerciseId, maxWeight).catchError((_) => false);
      }
      final volume = WorkoutLog.computeVolume(validSets);

      // For backdated entries, preserve the chosen day but stamp the
      // current time so multiple sessions on the same day stay ordered.
      final now = DateTime.now();
      final isToday = _logDate.year == now.year &&
          _logDate.month == now.month &&
          _logDate.day == now.day;
      final logDate = isToday
          ? now
          : DateTime(_logDate.year, _logDate.month, _logDate.day,
              now.hour, now.minute, now.second);

      final log = WorkoutLog(
        id: const Uuid().v4(),
        exerciseId: widget.exerciseId,
        exerciseName: widget.exerciseName,
        category: widget.category,
        date: logDate,
        sets: validSets,
        totalVolume: volume,
        isPersonalRecord: isPR,
      );

      await svc.saveLog(uid, log);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    if (isPR) HapticFeedback.mediumImpact();

    if (mounted) {
      setState(() { _saving = false; _isPR = isPR; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(isPR ? 'Session saved! New personal record!' : 'Session saved!'),
            ],
          ),
          backgroundColor: isPR ? AppColors.prGold : AppColors.accent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalUnit = ref.watch(unitPreferenceProvider);
    final unit = _unitOverride ?? globalUnit;
    final isBodyweight =
        widget.category == 'bodyweight' || widget.category == 'calisthenics';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.exerciseName, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_isPR) ...[
                  const SizedBox(width: 8),
                  const _PRBadge(),
                ],
              ],
            ),
          ],
        ),
        actions: [
          if (widget.category != 'bodyweight' &&
              widget.category != 'calisthenics' &&
              !_isCardio)
            TextButton(
              onPressed: () => _showPlateCalculator(context),
              child: Text('Plates', style: TextStyle(color: AppColors.accent)),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (widget.note.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(color: AppColors.accent, width: 3),
                              top: const BorderSide(color: AppColors.divider),
                              right: const BorderSide(color: AppColors.divider),
                              bottom: const BorderSide(color: AppColors.divider),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.sticky_note_2_outlined,
                                  size: 16, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.note,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          _SectionLabel(label: _logDateLabel(), isGhost: false),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _pickLogDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color:
                                        AppColors.accent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 12, color: AppColors.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Pick date',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!_isCardio && !isBodyweight)
                            _UnitToggle(
                              unit: unit,
                              onChanged: _setUnitOverride,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ..._sets.asMap().entries.map((entry) {
                        final i = entry.key;
                        final s = entry.value;
                        return _EditableSetRow(
                          key: ValueKey('${s.id}_$unit'),
                          setNumber: i + 1,
                          entry: s,
                          unit: unit,
                          bodyweight: widget.category == 'bodyweight' || widget.category == 'calisthenics',
                          isCardio: _isCardio,
                          distanceUnit: ref.watch(distanceUnitProvider),
                          onDelete: _sets.length > 1 ? () => _removeSet(i) : null,
                          onChanged: () => setState(() {}),
                        );
                      }),

                      const SizedBox(height: 12),
                      // Add set button
                      OutlinedButton.icon(
                        onPressed: _addSet,
                        icon: Icon(Icons.add, size: 18, color: AppColors.accent),
                        label: Text('Add Set', style: TextStyle(color: AppColors.accent)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.accent),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Last session summary bar
                if (_lastLog != null && _lastLog!.sets.isNotEmpty)
                  _LastSessionBar(
                    log: _lastLog!,
                    isBodyweight: widget.category == 'bodyweight' || widget.category == 'calisthenics',
                    isCardio: _isCardio,
                    weightUnit: unit,
                    distanceUnit: ref.watch(distanceUnitProvider),
                  ),

                // Sticky save button
                _StickyFooter(
                  saving: _saving,
                  onSave: _save,
                ),
              ],
            ),
    );
  }

  void _showPlateCalculator(BuildContext context) {
    final unit = ref.read(unitPreferenceProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PlateCalculatorWidget(unit: unit),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ──────────────────────────────────────────────
// Mutable set entry for current session
// ──────────────────────────────────────────────

class _SetEntry {
  final String id = const Uuid().v4();
  double weight;
  int reps;
  double distance;
  double durationMinutes;
  _SetEntry({
    required this.weight,
    required this.reps,
    this.distance = 0,
    this.durationMinutes = 0,
  });
}

// ──────────────────────────────────────────────
// Ghost set row (read-only, previous session)
// ──────────────────────────────────────────────

class _GhostSetRow extends StatelessWidget {
  final int setNumber;
  final WorkoutSet set;
  final String unit;
  final bool bodyweight;
  const _GhostSetRow({required this.setNumber, required this.set, required this.unit, this.bodyweight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.accent, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text('Set $setNumber',
                  style: const TextStyle(color: AppColors.textGhost, fontSize: 13)),
            ),
            Expanded(
              child: Text(
                bodyweight
                    ? '${set.reps} reps'
                    : '${_displayWeight(set.weight, unit)} $unit  ×  ${set.reps} reps',
                style: const TextStyle(color: AppColors.textGhost, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayWeight(double w, String unit) {
    if (unit == 'lb') {
      final lb = w * 2.20462;
      return lb % 1 == 0 ? lb.toStringAsFixed(0) : lb.toStringAsFixed(1);
    }
    return w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
  }
}

// ──────────────────────────────────────────────
// Editable set row (current session)
// ──────────────────────────────────────────────

class _EditableSetRow extends StatefulWidget {
  final int setNumber;
  final _SetEntry entry;
  final String unit;
  final bool bodyweight;
  final bool isCardio;
  final String distanceUnit;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;

  const _EditableSetRow({
    super.key,
    required this.setNumber,
    required this.entry,
    required this.unit,
    this.bodyweight = false,
    this.isCardio = false,
    this.distanceUnit = 'km',
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_EditableSetRow> createState() => _EditableSetRowState();
}

class _EditableSetRowState extends State<_EditableSetRow> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _durationCtrl;
  bool _showDelete = false;

  @override
  void initState() {
    super.initState();
    // Weight stored in kg internally; display in user's preferred unit.
    final displayWeight = widget.unit == 'lb'
        ? widget.entry.weight * 2.20462
        : widget.entry.weight;
    _weightCtrl = TextEditingController(
        text: displayWeight > 0 ? _fmt(displayWeight) : '');
    _repsCtrl = TextEditingController(
        text: widget.entry.reps > 0 ? widget.entry.reps.toString() : '');
    // Distance is stored in km internally; show in user's preferred unit.
    final displayDistance = widget.distanceUnit == 'mi'
        ? widget.entry.distance * 0.621371
        : widget.entry.distance;
    _distanceCtrl = TextEditingController(
        text: displayDistance > 0 ? _fmt(displayDistance) : '');
    _durationCtrl = TextEditingController(
        text: widget.entry.durationMinutes > 0 ? _fmt(widget.entry.durationMinutes) : '');
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _distanceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showDelete = !_showDelete),
      child: Dismissible(
        key: ValueKey(widget.entry.id),
        direction: widget.onDelete != null
            ? DismissDirection.endToStart
            : DismissDirection.none,
        onDismissed: (_) => widget.onDelete?.call(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text('Set ${widget.setNumber}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
                if (widget.isCardio) ...[
                  Expanded(
                    child: _NumberField(
                      controller: _distanceCtrl,
                      hint: '0',
                      suffix: widget.distanceUnit,
                      decimal: true,
                      wheelStep: widget.distanceUnit == 'mi' ? 0.5 : 1.0,
                      wheelMin: 0,
                      wheelMax: widget.distanceUnit == 'mi' ? 100 : 200,
                      onChanged: (v) {
                        final entered = double.tryParse(v) ?? 0;
                        // Always store in km internally.
                        widget.entry.distance = widget.distanceUnit == 'mi'
                            ? entered / 0.621371
                            : entered;
                        widget.onChanged();
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('•', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                  ),
                  Expanded(
                    child: _NumberField(
                      controller: _durationCtrl,
                      hint: '0',
                      suffix: 'min',
                      decimal: true,
                      wheelStep: 1,
                      wheelMin: 0,
                      wheelMax: 600,
                      onChanged: (v) {
                        widget.entry.durationMinutes = double.tryParse(v) ?? 0;
                        widget.onChanged();
                      },
                    ),
                  ),
                ] else ...[
                  if (!widget.bodyweight) ...[
                    Expanded(
                      child: _NumberField(
                        controller: _weightCtrl,
                        hint: '0',
                        suffix: widget.unit,
                        decimal: true,
                        wheelStep: widget.unit == 'lb' ? 5 : 2.5,
                        wheelMin: 0,
                        wheelMax: widget.unit == 'lb' ? 1000 : 500,
                        onChanged: (v) {
                          final entered = double.tryParse(v) ?? 0;
                          // Always store in kg internally.
                          widget.entry.weight = widget.unit == 'lb'
                              ? entered / 2.20462
                              : entered;
                          widget.onChanged();
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('×', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                    ),
                  ],
                  Expanded(
                    child: _NumberField(
                      controller: _repsCtrl,
                      hint: '0',
                      suffix: 'reps',
                      decimal: false,
                      wheelStep: 1,
                      wheelMin: 0,
                      wheelMax: 100,
                      onChanged: (v) {
                        widget.entry.reps = int.tryParse(v) ?? 0;
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
                if (_showDelete && widget.onDelete != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  ),
                ] else
                  const SizedBox(width: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool decimal;
  final ValueChanged<String> onChanged;
  final String? suffix;
  // Wheel-picker configuration. When wheelStep > 0 a small icon button is
  // shown to the right of the field that opens a CupertinoPicker.
  final double? wheelStep;
  final double? wheelMin;
  final double? wheelMax;

  const _NumberField({
    required this.controller,
    required this.hint,
    required this.decimal,
    required this.onChanged,
    this.suffix,
    this.wheelStep,
    this.wheelMin,
    this.wheelMax,
  });

  bool get _hasWheel =>
      wheelStep != null && wheelStep! > 0 && wheelMin != null && wheelMax != null;

  Future<void> _openWheel(BuildContext context) async {
    final current = double.tryParse(controller.text) ?? wheelMin!;
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _WheelPickerSheet(
        initial: current,
        step: wheelStep!,
        min: wheelMin!,
        max: wheelMax!,
        suffix: suffix ?? '',
        decimal: decimal,
      ),
    );
    if (picked != null) {
      final str = decimal
          ? (picked % 1 == 0
              ? picked.toStringAsFixed(0)
              : picked.toStringAsFixed(1))
          : picked.toStringAsFixed(0);
      controller.text = str;
      onChanged(str);
    }
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(decimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'\d+')),
      ],
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
        suffixText: suffix,
        suffixStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );

    if (!_hasWheel) return field;

    return Row(
      children: [
        Expanded(child: field),
        GestureDetector(
          onTap: () => _openWheel(context),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Icon(Icons.unfold_more,
                color: AppColors.accent, size: 18),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Wheel picker bottom sheet
// ──────────────────────────────────────────────

class _WheelPickerSheet extends StatefulWidget {
  final double initial;
  final double step;
  final double min;
  final double max;
  final String suffix;
  final bool decimal;
  const _WheelPickerSheet({
    required this.initial,
    required this.step,
    required this.min,
    required this.max,
    required this.suffix,
    required this.decimal,
  });

  @override
  State<_WheelPickerSheet> createState() => _WheelPickerSheetState();
}

class _WheelPickerSheetState extends State<_WheelPickerSheet> {
  late final List<double> _values;
  late int _index;

  @override
  void initState() {
    super.initState();
    _values = [];
    for (double v = widget.min; v <= widget.max + 1e-9; v += widget.step) {
      _values.add(double.parse(v.toStringAsFixed(2)));
    }
    int closest = 0;
    double bestDiff = double.infinity;
    for (var i = 0; i < _values.length; i++) {
      final d = (_values[i] - widget.initial).abs();
      if (d < bestDiff) {
        bestDiff = d;
        closest = i;
      }
    }
    _index = closest;
  }

  String _fmt(double v) {
    if (!widget.decimal) return v.toStringAsFixed(0);
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select ${widget.suffix}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: CupertinoPicker(
                scrollController:
                    FixedExtentScrollController(initialItem: _index),
                itemExtent: 40,
                backgroundColor: AppColors.surface,
                selectionOverlay: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.accent, width: 1),
                      bottom: BorderSide(color: AppColors.accent, width: 1),
                    ),
                  ),
                ),
                onSelectedItemChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _index = i);
                },
                children: _values
                    .map((v) => Center(
                          child: Text(
                            '${_fmt(v)} ${widget.suffix}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _values[_index]),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Per-exercise kg/lb unit toggle
// ──────────────────────────────────────────────

class _UnitToggle extends StatelessWidget {
  final String unit;
  final ValueChanged<String> onChanged;
  const _UnitToggle({required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill('kg'),
          _pill('lb'),
        ],
      ),
    );
  }

  Widget _pill(String value) {
    final selected = unit == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Section label
// ──────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isGhost;
  const _SectionLabel({required this.label, required this.isGhost});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: isGhost ? AppColors.textGhost : AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// PR badge
// ──────────────────────────────────────────────
// Last session summary bar
// ──────────────────────────────────────────────

class _LastSessionBar extends StatelessWidget {
  final WorkoutLog log;
  final bool isBodyweight;
  final bool isCardio;
  final String weightUnit;
  final String distanceUnit;
  const _LastSessionBar({
    required this.log,
    required this.isBodyweight,
    this.isCardio = false,
    this.weightUnit = 'kg',
    this.distanceUnit = 'km',
  });

  @override
  Widget build(BuildContext context) {
    final sets = log.sets;
    String summary;
    if (isCardio) {
      final totalDistKm = sets.fold<double>(0, (sum, s) => sum + s.distance);
      final totalMin = sets.fold<double>(0, (sum, s) => sum + s.durationMinutes);
      final dist = distanceUnit == 'mi' ? totalDistKm * 0.621371 : totalDistKm;
      final distStr = dist % 1 == 0 ? dist.toStringAsFixed(0) : dist.toStringAsFixed(2);
      final minStr = totalMin % 1 == 0 ? totalMin.toStringAsFixed(0) : totalMin.toStringAsFixed(1);
      summary = '$distStr $distanceUnit in $minStr min';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 8),
            const Text('Last session: ',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            Expanded(
              child: Text(summary,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
    }

    final topSet = sets.reduce((a, b) => a.weight > b.weight ? a : b);
    final allSameWeight = sets.every((s) => s.weight == topSet.weight);
    final allSameReps = sets.every((s) => s.reps == topSet.reps);

    double toDisplay(double kg) => weightUnit == 'lb' ? kg * 2.20462 : kg;
    String fmtW(double kg) {
      final v = toDisplay(kg);
      return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    }

    if (isBodyweight) {
      if (allSameReps) {
        summary = '${sets.length} sets of ${topSet.reps} reps';
      } else {
        summary = '${sets.asMap().entries.map((e) => '${e.value.reps}').join(' / ')} reps';
      }
    } else {
      final w = fmtW(topSet.weight);
      if (allSameWeight && allSameReps) {
        summary = '${sets.length} sets of $w $weightUnit × ${topSet.reps} reps';
      } else if (allSameWeight) {
        summary = '$w $weightUnit — ${sets.asMap().entries.map((e) => '${e.value.reps}').join(' / ')} reps';
      } else {
        summary = sets.map((s) => '${fmtW(s.weight)}×${s.reps}').join('  ');
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Text('Last session: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(summary,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────

class _PRBadge extends StatelessWidget {
  const _PRBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.prGold,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PR',
        style: TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Sticky save footer
// ──────────────────────────────────────────────

class _StickyFooter extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  const _StickyFooter({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: saving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.accent.withOpacity(0.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: saving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Session'),
        ),
      ),
    );
  }
}
