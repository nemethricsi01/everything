import 'dart:math';

const List<double> e6 = [1.0, 1.5, 2.2, 3.3, 4.7, 6.8];

const List<double> e12 = [1.0, 1.2, 1.5, 1.8, 2.2, 2.7, 3.3, 3.9, 4.7, 5.6, 6.8, 8.2];

const List<double> e24 = [
  1.0, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2.0, 2.2, 2.4, 2.7, 3.0, //
  3.3, 3.6, 3.9, 4.3, 4.7, 5.1, 5.6, 6.2, 6.8, 7.5, 8.2, 9.1,
];

final List<double> e96 = [
  for (var i = 0; i < 96; i++) (pow(10, i / 96) * 100).round() / 100,
];

List<double> _candidates(double v, List<double> series) {
  final decade = (log(v) / ln10).floor();
  final scale = pow(10, decade).toDouble();
  return [
    for (final s in series) s * scale,
    10 * scale,
  ];
}

/// Closest standard value to [v] in the given E-series.
double? eNearest(double v, List<double> series) {
  if (!(v > 0) || !v.isFinite) return null;
  var best = double.nan;
  var bestDist = double.infinity;
  for (final c in _candidates(v, series)) {
    final d = (log(c / v)).abs();
    if (d < bestDist) {
      bestDist = d;
      best = c;
    }
  }
  return best;
}

/// Smallest standard value that is >= [v] (safe pick for e.g. LED resistors).
double? eNextUp(double v, List<double> series) {
  if (!(v > 0) || !v.isFinite) return null;
  for (final c in _candidates(v, series)) {
    if (c >= v * (1 - 1e-9)) return c;
  }
  return null;
}
