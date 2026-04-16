import 'dart:ui';
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
import '../../shared/widgets/category_video_background.dart';

class LoggingScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String category;
  final String note;
  final String? trackingType;
  final bool plateable;

  const LoggingScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
    this.note = '',
    this.trackingType,
    this.plateable = false,
  });

  @override
  ConsumerState<LoggingScreen> createState() => _LoggingScreenState();
}

class _LoggingScreenState extends ConsumerState<LoggingScreen> {
  WorkoutLog? _lastLog;
  List<WorkoutLog> _recentSessions = const [];
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

    final sessions = await ref
        .read(workoutServiceProvider)
        .getRecentSessions(uid, widget.exerciseId, limit: 3)
        .catchError((_) => <WorkoutLog>[]);
    final last = sessions.isNotEmpty ? sessions.first : null;

    if (mounted) {
      setState(() {
        _lastLog = last;
        _recentSessions = sessions;
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

  // Effective tracking mode for this screen. Resolves, in order, from the
  // explicit trackingType passed in, then falls back to category conventions.
  //   'strength'   — weight × reps
  //   'bodyweight' — reps only
  //   'cardio'     — distance + duration
  //   'time'       — duration only
  //   'laps_time'  — pool lengths + duration
  String get _tracking {
    final t = widget.trackingType;
    if (t != null && t.isNotEmpty) return t;
    if (widget.category == 'cardio') return 'cardio';
    if (widget.category == 'bodyweight' || widget.category == 'calisthenics') {
      return 'bodyweight';
    }
    return 'strength';
  }

  bool get _isStrength => _tracking == 'strength';

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final List<WorkoutSet> validSets;
    String emptyMessage = 'Add at least one set with weight and reps.';
    switch (_tracking) {
      case 'cardio':
        validSets = _sets
            .where((s) => s.distance > 0 || s.durationMinutes > 0)
            .map((s) => WorkoutSet(
                  weight: 0,
                  reps: 0,
                  distance: s.distance,
                  durationMinutes: s.durationMinutes,
                ))
            .toList();
        emptyMessage = 'Add at least one entry with distance or time.';
        break;
      case 'time':
        validSets = _sets
            .where((s) => s.durationMinutes > 0)
            .map((s) => WorkoutSet(
                  weight: 0,
                  reps: 0,
                  durationMinutes: s.durationMinutes,
                ))
            .toList();
        emptyMessage = 'Add at least one set with a duration.';
        break;
      case 'laps_time':
        validSets = _sets
            .where((s) => s.reps > 0 || s.durationMinutes > 0)
            .map((s) => WorkoutSet(
                  weight: 0,
                  reps: s.reps,
                  durationMinutes: s.durationMinutes,
                ))
            .toList();
        emptyMessage = 'Add at least one entry with lengths or time.';
        break;
      case 'bodyweight':
        validSets = _sets
            .where((s) => s.reps > 0)
            .map((s) => WorkoutSet(weight: 0, reps: s.reps))
            .toList();
        emptyMessage = 'Add at least one set with reps.';
        break;
      case 'strength':
      default:
        validSets = _sets
            .where((s) => s.weight > 0 && s.reps > 0)
            .map((s) => WorkoutSet(weight: s.weight, reps: s.reps))
            .toList();
        emptyMessage = 'Add at least one set with weight and reps.';
        break;
    }

    if (validSets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage)),
      );
      return;
    }

    setState(() => _saving = true);

    bool isPR = false;
    try {
      final svc = ref.read(workoutServiceProvider);
      // PR tracking only makes sense for weighted strength work.
      if (_isStrength) {
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                widget.exerciseName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isPR) ...[
              const SizedBox(width: 8),
              const _PRBadge(),
            ],
          ],
        ),
        actions: [
          // Pin to Quick Log bar
          Builder(builder: (context) {
            final pinned =
                ref.watch(pinnedQuickLogProvider).contains(widget.exerciseId);
            return IconButton(
              tooltip: pinned ? 'Unpin from Quick Log' : 'Pin to Quick Log',
              icon: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: pinned ? AppColors.accent : AppColors.textSecondary,
              ),
              onPressed: () async {
                await ref
                    .read(pinnedQuickLogProvider.notifier)
                    .toggle(widget.exerciseId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppColors.surface,
                    content: Text(
                      ref
                              .read(pinnedQuickLogProvider)
                              .contains(widget.exerciseId)
                          ? 'Pinned to Quick Log'
                          : 'Unpinned from Quick Log',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                );
              },
            );
          }),
          // Plate calculator only shows for barbell / plate-loaded exercises
          // where the user actually needs to figure out what plates to put on.
          if (widget.plateable && _isStrength)
            TextButton(
              onPressed: () => _showPlateCalculator(context),
              child: Text('Plates', style: TextStyle(color: AppColors.accent)),
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : CategoryVideoBackground(
              category: widget.category,
              child: Column(
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
                                  style: TextStyle(
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
                                color: AppColors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
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
                          // Unit toggle (kg/lb) only applies to strength work.
                          if (_isStrength)
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
                          key: ValueKey('${s.id}_${unit}_$_tracking'),
                          setNumber: i + 1,
                          entry: s,
                          unit: unit,
                          tracking: _tracking,
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

                // Last few sessions summary bar
                if (_recentSessions.isNotEmpty)
                  _LastSessionBar(
                    sessions: _recentSessions,
                    tracking: _tracking,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.25),
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
                        style: TextStyle(color: AppColors.textGhost, fontSize: 13)),
                  ),
                  Expanded(
                    child: Text(
                      bodyweight
                          ? '${set.reps} reps'
                          : '${_displayWeight(set.weight, unit)} $unit  ×  ${set.reps} reps',
                      style: TextStyle(color: AppColors.textGhost, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
  final String tracking; // 'strength' | 'bodyweight' | 'cardio' | 'time' | 'laps_time'
  final String distanceUnit;
  final VoidCallback? onDelete;
  final VoidCallback onChanged;

  const _EditableSetRow({
    super.key,
    required this.setNumber,
    required this.entry,
    required this.unit,
    required this.tracking,
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

  // Builds the input fields appropriate to the active tracking type. Each
  // field returns either a _NumberField wrapped in Expanded or a small
  // separator so the parent Row can spread children evenly.
  List<Widget> _buildFieldsForTracking() {
    Widget separator(String glyph) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(glyph,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 18)),
        );

    Widget weightField() => Expanded(
          child: _NumberField(
            controller: _weightCtrl,
            hint: '',
            suffix: widget.unit,
            decimal: true,
            wheelStep: widget.unit == 'lb' ? 5 : 2.5,
            wheelMin: 0,
            wheelMax: widget.unit == 'lb' ? 1000 : 500,
            onChanged: (v) {
              final entered = double.tryParse(v) ?? 0;
              widget.entry.weight =
                  widget.unit == 'lb' ? entered / 2.20462 : entered;
              widget.onChanged();
            },
          ),
        );

    Widget repsField({String suffix = 'reps', double wheelMax = 100}) =>
        Expanded(
          child: _NumberField(
            controller: _repsCtrl,
            hint: '',
            suffix: suffix,
            decimal: false,
            wheelStep: 1,
            wheelMin: 0,
            wheelMax: wheelMax,
            onChanged: (v) {
              widget.entry.reps = int.tryParse(v) ?? 0;
              widget.onChanged();
            },
          ),
        );

    Widget distanceField() => Expanded(
          child: _NumberField(
            controller: _distanceCtrl,
            hint: '',
            suffix: widget.distanceUnit,
            decimal: true,
            wheelStep: widget.distanceUnit == 'mi' ? 0.5 : 1.0,
            wheelMin: 0,
            wheelMax: widget.distanceUnit == 'mi' ? 100 : 200,
            onChanged: (v) {
              final entered = double.tryParse(v) ?? 0;
              widget.entry.distance =
                  widget.distanceUnit == 'mi' ? entered / 0.621371 : entered;
              widget.onChanged();
            },
          ),
        );

    Widget durationField() => Expanded(
          child: _NumberField(
            controller: _durationCtrl,
            hint: '',
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
        );

    switch (widget.tracking) {
      case 'cardio':
        return [distanceField(), separator('•'), durationField()];
      case 'time':
        return [durationField()];
      case 'laps_time':
        return [
          repsField(suffix: 'lengths', wheelMax: 200),
          separator('•'),
          durationField(),
        ];
      case 'bodyweight':
        return [repsField()];
      case 'strength':
      default:
        return [weightField(), separator('×'), repsField()];
    }
  }

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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text('Set ${widget.setNumber}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ),
                ..._buildFieldsForTracking(),
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
    final textField = TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(decimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'\d+')),
      ],
      textAlign: TextAlign.right,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );

    // Always-visible unit label next to the field so users can see
    // "kg"/"lb"/"reps"/"min" at a glance without focusing the input.
    final field = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: textField),
        if (suffix != null && suffix!.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(
            suffix!,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
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
              style: TextStyle(
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
                            style: TextStyle(
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
                    child: Text('Cancel',
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
  final List<WorkoutLog> sessions;
  final String tracking; // 'strength' | 'bodyweight' | 'cardio' | 'time' | 'laps_time'
  final String weightUnit;
  final String distanceUnit;
  const _LastSessionBar({
    required this.sessions,
    required this.tracking,
    this.weightUnit = 'kg',
    this.distanceUnit = 'km',
  });

  double _toDisplay(double kg) => weightUnit == 'lb' ? kg * 2.20462 : kg;
  String _fmtW(double kg) {
    final v = _toDisplay(kg);
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  String _fmtMin(double min) =>
      min % 1 == 0 ? min.toStringAsFixed(0) : min.toStringAsFixed(1);

  String _summarise(WorkoutLog log) {
    final sets = log.sets;
    if (sets.isEmpty) return '—';

    switch (tracking) {
      case 'cardio':
        {
          final totalDistKm =
              sets.fold<double>(0, (sum, s) => sum + s.distance);
          final totalMin =
              sets.fold<double>(0, (sum, s) => sum + s.durationMinutes);
          final dist =
              distanceUnit == 'mi' ? totalDistKm * 0.621371 : totalDistKm;
          final distStr = dist % 1 == 0
              ? dist.toStringAsFixed(0)
              : dist.toStringAsFixed(2);
          return '$distStr $distanceUnit in ${_fmtMin(totalMin)} min';
        }
      case 'time':
        {
          final totalMin =
              sets.fold<double>(0, (sum, s) => sum + s.durationMinutes);
          if (sets.length == 1) return '${_fmtMin(totalMin)} min';
          return '${sets.length} sets — ${_fmtMin(totalMin)} min total';
        }
      case 'laps_time':
        {
          final totalLengths = sets.fold<int>(0, (sum, s) => sum + s.reps);
          final totalMin =
              sets.fold<double>(0, (sum, s) => sum + s.durationMinutes);
          return '$totalLengths lengths in ${_fmtMin(totalMin)} min';
        }
      case 'bodyweight':
        {
          final topReps = sets.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
          final allSameReps = sets.every((s) => s.reps == topReps);
          if (allSameReps) {
            return '${sets.length} sets of $topReps reps';
          }
          return '${sets.map((s) => s.reps).join(' / ')} reps';
        }
      case 'strength':
      default:
        {
          final topSet = sets.reduce((a, b) => a.weight > b.weight ? a : b);
          final allSameWeight = sets.every((s) => s.weight == topSet.weight);
          final allSameReps = sets.every((s) => s.reps == topSet.reps);
          final w = _fmtW(topSet.weight);
          if (allSameWeight && allSameReps) {
            return '${sets.length} sets of $w $weightUnit × ${topSet.reps} reps';
          }
          if (allSameWeight) {
            return '$w $weightUnit — ${sets.map((s) => s.reps).join(' / ')} reps';
          }
          return sets.map((s) => '${_fmtW(s.weight)}×${s.reps}').join('  ');
        }
    }
  }

  String _relativeDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    // Label rotates between "Last session" / "Previous" / "Earlier".
    const labels = ['Last session', 'Previous', 'Earlier'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sessions.length && i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  i == 0 ? Icons.history : Icons.circle,
                  color: AppColors.textSecondary,
                  size: i == 0 ? 16 : 5,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: Text(
                    '${labels[i]}:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _summarise(sessions[i]),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _relativeDate(sessions[i].date),
                  style: TextStyle(
                    color: AppColors.textGhost,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
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
      decoration: BoxDecoration(
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
