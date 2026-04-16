import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/models/exercise.dart';
import '../../shared/models/workout_log.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/category_video_background.dart';
import '../../shared/widgets/mini_progress_chart.dart';
import 'logging_screen.dart';

class SubcategoryScreen extends ConsumerStatefulWidget {
  final String category;
  const SubcategoryScreen({super.key, required this.category});

  @override
  ConsumerState<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends ConsumerState<SubcategoryScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final Set<String> _expanded = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteCustom(Exercise ex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete custom workout?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Text(
          '"${ex.name}" will be removed from your list. Existing logs for it will stay in your history.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(customExercisesProvider.notifier).remove(ex.id);
    }
  }

  Future<void> _openCustomDialog(String subcategory) async {
    final result = await showDialog<_NewCustomResult>(
      context: context,
      builder: (_) => _NewCustomDialog(
        subcategoryLabel:
            kSubcategoryLabels[subcategory] ?? subcategory,
      ),
    );
    if (result == null || !mounted) return;

    final ex = await ref.read(customExercisesProvider.notifier).add(
          name: result.name,
          category: widget.category,
          subcategory: subcategory,
          note: result.note,
        );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoggingScreen(
          exerciseId: ex.id,
          exerciseName: ex.name,
          category: ex.category,
          trackingType: ex.trackingType,
          plateable: ex.plateable,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subcategories =
        kSubcategoriesByCategory[widget.category] ?? const <String>[];
    final categoryLabel = kCategoryLabels[widget.category] ?? widget.category;
    final query = _searchQuery.toLowerCase();
    final isSearching = query.isNotEmpty;
    final customExercises = ref.watch(customExercisesProvider);
    final accent = ref.watch(displayAccentProvider);

    // Stream logs so we can compute per-subcategory progression charts.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final logsStream = uid != null
        ? ref.watch(workoutServiceProvider).streamAllLogs(uid)
        : const Stream<List<WorkoutLog>>.empty();

    // Map exerciseId → subcategory for filtering logs.
    final exerciseSubMap = <String, String>{
      for (final ex in kExerciseList)
        if (ex.category == widget.category) ex.id: ex.subcategory,
      for (final ex in customExercises)
        if (ex.category == widget.category) ex.id: ex.subcategory,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<WorkoutLog>>(
        stream: logsStream,
        builder: (context, snap) {
          final allLogs = snap.data ?? [];
          // Group logs by subcategory.
          final logsBySub = <String, List<WorkoutLog>>{};
          for (final log in allLogs) {
            final sub = exerciseSubMap[log.exerciseId];
            if (sub == null) continue;
            logsBySub.putIfAbsent(sub, () => []).add(log);
          }

          return CategoryVideoBackground(
            category: widget.category,
            child: Column(
            children: [
              // Search field
              Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: AppColors.textSecondary, size: 18),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        }),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface.withValues(alpha: 0.25),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),

          // Subcategory expandable list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: subcategories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final sub = subcategories[i];
                final label = kSubcategoryLabels[sub] ?? sub;
                final builtIn = kExerciseList.where((e) =>
                    e.category == widget.category && e.subcategory == sub);
                final customs = customExercises.where((e) =>
                    e.category == widget.category && e.subcategory == sub);
                final exercises = [...builtIn, ...customs]
                    .where((e) =>
                        query.isEmpty ||
                        e.name.toLowerCase().contains(query))
                    .toList();

                // When searching, hide subcategories with no matches and
                // auto-expand the ones that do.
                if (isSearching && exercises.isEmpty) {
                  return const SizedBox.shrink();
                }
                final isOpen = isSearching || _expanded.contains(sub);

                // Build the whole subcategory block as a Column of separate
                // glass pills so the video background bleeds through the gaps
                // between the header and each exercise row.
                return Column(
                  children: [
                    // ── Header pill ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Material(
                          color: AppColors.surface.withValues(alpha: 0.25),
                          child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          if (isSearching) return;
                          setState(() {
                            if (_expanded.contains(sub)) {
                              _expanded.remove(sub);
                            } else {
                              _expanded.add(sub);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          child: Builder(builder: (_) {
                            final subLogs = logsBySub[sub] ?? [];
                            final progression = computeProgression(subLogs);
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(label,
                                          style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                          subLogs.isEmpty
                                              ? 'No workouts logged'
                                              : '${exercises.length} exercise${exercises.length == 1 ? '' : 's'}  ·  ${subLogs.length} log${subLogs.length == 1 ? '' : 's'}',
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                                // Mini progression chart (only when enough data)
                                if (progression.length >= 2) ...[
                                  SizedBox(
                                    width: 56,
                                    height: 28,
                                    child: MiniProgressChart(
                                      points: progression,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Icon(
                                  isOpen
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                        ),
                      ),
                    ),
                    // ── Expanded exercise rows (each its own glass pill) ──
                    if (isOpen) ...[
                      const SizedBox(height: 10),
                      ...exercises.map((ex) {
                        final tile = Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Material(
                                color: AppColors.surface
                                    .withValues(alpha: 0.15),
                                child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoggingScreen(
                                  exerciseId: ex.id,
                                  exerciseName: ex.name,
                                  category: ex.category,
                                  note: ex.note,
                                  trackingType: ex.trackingType,
                                  plateable: ex.plateable,
                                ),
                              ),
                            ),
                            onLongPress: ex.isCustom
                                ? () => _confirmDeleteCustom(ex)
                                : null,
                            child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(ex.name,
                                                    style: TextStyle(
                                                        color: AppColors
                                                            .textPrimary,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                              ),
                                              if (ex.isCustom) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accent
                                                        .withValues(
                                                            alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    'custom',
                                                    style: TextStyle(
                                                      color: AppColors.accent,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (ex.note.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 2),
                                              child: Text(
                                                ex.note,
                                                style: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Log',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                              ),
                            ),
                          ),
                          );
                          if (!ex.isCustom) return tile;
                          return Dismissible(
                            key: ValueKey('ex_${ex.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppColors.error,
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white),
                            ),
                            confirmDismiss: (_) async {
                              await _confirmDeleteCustom(ex);
                              // The provider removes the item; returning false
                              // avoids Dismissible removing the widget itself
                              // (the list rebuilds from provider state).
                              return false;
                            },
                            child: tile,
                          );
                        }),
                      // Add custom workout tile (hidden during search)
                      if (!isSearching)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Material(
                                color: AppColors.surface
                                    .withValues(alpha: 0.15),
                                child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openCustomDialog(sub),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline,
                                      color: AppColors.accent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add custom workout',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// New custom workout dialog
// ──────────────────────────────────────────────

class _NewCustomResult {
  final String name;
  final String note;
  const _NewCustomResult(this.name, this.note);
}

class _NewCustomDialog extends StatefulWidget {
  final String subcategoryLabel;
  const _NewCustomDialog({required this.subcategoryLabel});

  @override
  State<_NewCustomDialog> createState() => _NewCustomDialogState();
}

class _NewCustomDialogState extends State<_NewCustomDialog> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        'New ${widget.subcategoryLabel} workout',
        style: TextStyle(
            color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Exercise name',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. pull-ups with extra weight',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              hintStyle: TextStyle(color: AppColors.textGhost, fontSize: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
                context, _NewCustomResult(name, _noteCtrl.text.trim()));
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Create & log'),
        ),
      ],
    );
  }
}
