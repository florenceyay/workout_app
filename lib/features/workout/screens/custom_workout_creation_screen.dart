import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/exercise.dart';
import 'logging_screen.dart';

class CustomWorkoutCreationScreen extends ConsumerStatefulWidget {
  const CustomWorkoutCreationScreen({super.key});

  @override
  ConsumerState<CustomWorkoutCreationScreen> createState() =>
      _CustomWorkoutCreationScreenState();
}

class _CustomWorkoutCreationScreenState
    extends ConsumerState<CustomWorkoutCreationScreen> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _trackingType = 'strength'; // 'strength' | 'cardio' | 'bodyweight'
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a workout name.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Map tracking types → effective category for logging screen behaviour.
      // Bodyweight uses calisthenics category so the logging screen shows
      // reps only. Custom + cardio uses 'custom' but trackingType = 'cardio'.
      final effectiveCategory =
          _trackingType == 'bodyweight' ? 'calisthenics' : 'custom';
      final storedType =
          _trackingType == 'bodyweight' ? 'bodyweight' : _trackingType;

      final ex = await ref.read(customExercisesProvider.notifier).add(
            name: name,
            category: effectiveCategory,
            subcategory: 'custom',
            note: _noteCtrl.text.trim(),
            trackingType: storedType,
          );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoggingScreen(
            exerciseId: ex.id,
            exerciseName: ex.name,
            category: ex.category,
            note: ex.note,
            trackingType: ex.trackingType,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _confirmDelete(Exercise ex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete custom workout?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Text(
          '"${ex.name}" will be removed. Existing logs will stay in your history.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
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

  @override
  Widget build(BuildContext context) {
    final customs = ref.watch(customExercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Workout',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Existing custom workouts ──
          if (customs.isNotEmpty) ...[
            const Text(
              'Your custom workouts',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            ...customs.map((ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey('custom_${ex.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      await _confirmDelete(ex);
                      return false;
                    },
                    child: _ExistingCustomTile(
                      exercise: ex,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoggingScreen(
                            exerciseId: ex.id,
                            exerciseName: ex.name,
                            category: ex.category,
                            note: ex.note,
                            trackingType: ex.trackingType,
                          ),
                        ),
                      ),
                      onLongPress: () => _confirmDelete(ex),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),
          ],

          // ── Create new ──
          const Text(
            'Create new workout',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),

          // Name field
          TextField(
            controller: _nameCtrl,
            autofocus: customs.isEmpty,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Workout name',
              hintText: 'e.g. Kickboxing, Rock Climbing',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintStyle:
                  const TextStyle(color: AppColors.textGhost, fontSize: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accent, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: 14),

          // Note field (optional)
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. with resistance band, at the park',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              hintStyle:
                  const TextStyle(color: AppColors.textGhost, fontSize: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accent, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
          ),
          const SizedBox(height: 22),

          // Tracking type selector
          const Text(
            'What do you want to track?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          _TrackingOption(
            title: 'Weight + Reps',
            subtitle: 'Track weight, reps, and sets',
            icon: Icons.fitness_center,
            selected: _trackingType == 'strength',
            onTap: () => setState(() => _trackingType = 'strength'),
          ),
          const SizedBox(height: 8),
          _TrackingOption(
            title: 'Distance / Time',
            subtitle: 'Track distance, duration, or both',
            icon: Icons.directions_run,
            selected: _trackingType == 'cardio',
            onTap: () => setState(() => _trackingType = 'cardio'),
          ),
          const SizedBox(height: 8),
          _TrackingOption(
            title: 'Reps only',
            subtitle: 'Track sets and reps (bodyweight)',
            icon: Icons.accessibility_new,
            selected: _trackingType == 'bodyweight',
            onTap: () => setState(() => _trackingType = 'bodyweight'),
          ),
          const SizedBox(height: 28),

          // Create button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor: AppColors.divider,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create & Log',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Tracking type option card
// ──────────────────────────────────────────────

class _TrackingOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TrackingOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: AppColors.accent, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (selected ? AppColors.accent : AppColors.textSecondary)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? AppColors.accent : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: AppColors.accent, size: 22)
            else
              Icon(Icons.circle_outlined,
                  color: AppColors.textGhost, size: 22),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Existing custom workout tile
// ──────────────────────────────────────────────

class _ExistingCustomTile extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ExistingCustomTile({
    required this.exercise,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final typeLabel = switch (exercise.trackingType) {
      'cardio' => 'Distance / Time',
      'bodyweight' => 'Reps only',
      _ => 'Weight + Reps',
    };

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          exercise.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (exercise.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      exercise.note,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(20),
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
    );
  }
}
