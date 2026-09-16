import 'dart:math' as math;

/// Exact swept sphere against an axis-aligned box. Splitting at box planes
/// makes squared distance a quadratic on each interval, including rounded
/// corners. A vertical capsule reduces to this by expanding the box along Y
/// by the capsule's half-segment length.
bool sweptSphereBox({
  required List<double> from,
  required List<double> to,
  required List<double> min,
  required List<double> max,
  required double radius,
}) {
  final times = <double>[0, 1];
  for (var axis = 0; axis < 3; axis++) {
    final delta = to[axis] - from[axis];
    if (delta.abs() < 1e-12) continue;
    for (final plane in [min[axis], max[axis]]) {
      final t = (plane - from[axis]) / delta;
      if (t > 0 && t < 1) times.add(t);
    }
  }
  times.sort();
  double distanceSquared(double t) {
    var d = 0.0;
    for (var axis = 0; axis < 3; axis++) {
      final value = from[axis] + (to[axis] - from[axis]) * t;
      final separation = math.max(
        min[axis] - value,
        math.max(0.0, value - max[axis]),
      );
      d += separation * separation;
    }
    return d;
  }

  for (var i = 1; i < times.length; i++) {
    final lo = times[i - 1], hi = times[i], mid = (lo + hi) / 2;
    var a = 0.0, b = 0.0;
    for (var axis = 0; axis < 3; axis++) {
      final delta = to[axis] - from[axis], sample = from[axis] + delta * mid;
      if (sample >= min[axis] && sample <= max[axis]) continue;
      final boundary = sample < min[axis] ? min[axis] : max[axis];
      a += delta * delta;
      b += (from[axis] - boundary) * delta;
    }
    final closest = a > 1e-12 ? (-b / a).clamp(lo, hi) : lo;
    if (distanceSquared(closest) <= radius * radius) return true;
  }
  return false;
}
