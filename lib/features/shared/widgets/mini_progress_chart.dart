import 'package:flutter/material.dart';
import '../models/workout_log.dart';

/// A tiny sparkline chart that visualises a workout progression trend.
/// Shows 2–4 averaged data-point buckets with a thin line + dots.
/// Hides itself (returns SizedBox.shrink) if fewer than 2 points are given.
class MiniProgressChart extends StatelessWidget {
  final List<double> points;
  final Color color;
  const MiniProgressChart({super.key, required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();
    return CustomPaint(
      painter: _MiniProgressPainter(points: points, color: color),
    );
  }
}

class _MiniProgressPainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _MiniProgressPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final minV = points.reduce((a, b) => a < b ? a : b);
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);

    const padY = 4.0;
    final usableH = size.height - padY * 2;

    Offset pointAt(int i) {
      final x = points.length == 1
          ? size.width / 2
          : (i / (points.length - 1)) * size.width;
      final norm = (points[i] - minV) / range;
      final y = padY + (1 - norm) * usableH;
      return Offset(x, y);
    }

    // Faint baseline
    final baselinePaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      baselinePaint,
    );

    // Line path
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    // Dots
    final dotPaint = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(pointAt(i), 1.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniProgressPainter old) =>
      old.points != points || old.color != color;
}

/// Splits [logs] into up to 4 chronological buckets and returns the average
/// "score" per bucket.  Score per log:
///   - weighted lifts → total volume (weight × reps across sets)
///   - bodyweight     → total reps
///   - cardio         → distance (fallback to duration)
///
/// Returns an empty list when fewer than 2 logs exist.
List<double> computeProgression(List<WorkoutLog> logs) {
  if (logs.length < 2) return const [];
  final sorted = [...logs]..sort((a, b) => a.date.compareTo(b.date));

  double scoreFor(WorkoutLog l) {
    final cat = l.category;
    if (cat == 'cardio') {
      final dist = l.sets.fold<double>(0, (s, x) => s + x.distance);
      if (dist > 0) return dist;
      return l.sets.fold<double>(0, (s, x) => s + x.durationMinutes);
    }
    if (cat == 'bodyweight' || cat == 'calisthenics') {
      return l.sets.fold<double>(0, (s, x) => s + x.reps).toDouble();
    }
    if (l.totalVolume > 0) return l.totalVolume;
    return l.sets.fold<double>(0, (s, x) => s + x.weight * x.reps);
  }

  final bucketCount = sorted.length >= 4 ? 4 : sorted.length;
  final buckets = List.generate(bucketCount, (_) => <double>[]);
  for (var i = 0; i < sorted.length; i++) {
    final b = ((i * bucketCount) ~/ sorted.length).clamp(0, bucketCount - 1);
    buckets[b].add(scoreFor(sorted[i]));
  }
  return [
    for (final b in buckets)
      if (b.isEmpty) 0.0 else b.reduce((a, c) => a + c) / b.length,
  ];
}
