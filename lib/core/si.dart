import 'dart:math';

/// SI prefix multipliers accepted when typing values (case-sensitive:
/// `m` is milli, `M` is mega).
const Map<String, double> _prefixMultipliers = {
  'T': 1e12,
  'G': 1e9,
  'M': 1e6,
  'k': 1e3,
  'K': 1e3,
  'm': 1e-3,
  'u': 1e-6,
  'µ': 1e-6,
  'μ': 1e-6,
  'n': 1e-9,
  'p': 1e-12,
  'f': 1e-15,
};

const Map<int, String> _formatPrefixes = {
  12: 'T',
  9: 'G',
  6: 'M',
  3: 'k',
  0: '',
  -3: 'm',
  -6: 'µ',
  -9: 'n',
  -12: 'p',
  -15: 'f',
};

// "4.7k", "100nF", "2.2uF", "1e3", "10 mA"
final _plain = RegExp(
    r'^([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)([TGMkKmuµμnpf]?)([a-zA-ZΩΩ°%]*)$');
// Resistor-style "4k7", "4R7", "2u2", "1M5"
final _rkm = RegExp(r'^(\d+)([TGMkKmuµμnpfRr])(\d+)([a-zA-ZΩΩ]*)$');

/// Parses a number typed by the user, with optional SI prefix and unit.
/// Returns null when the text can't be understood.
double? parseSi(String input) {
  final s = input.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  if (s.isEmpty) return null;

  final r = _rkm.firstMatch(s);
  if (r != null) {
    final p = r.group(2)!;
    final mult = (p == 'R' || p == 'r') ? 1.0 : _prefixMultipliers[p]!;
    return double.parse('${r.group(1)}.${r.group(3)}') * mult;
  }

  final m = _plain.firstMatch(s);
  if (m == null) return null;
  var number = m.group(1)!;
  if (number.endsWith('.')) number += '0';
  final base = double.tryParse(number);
  if (base == null) return null;
  final p = m.group(2)!;
  return p.isEmpty ? base : base * _prefixMultipliers[p]!;
}

/// Formats a plain number with [sig] significant digits, trimming zeros.
String formatNumber(double v, {int sig = 4}) {
  if (!v.isFinite) return '—';
  if (v == 0) return '0';
  var s = v.toStringAsPrecision(sig);
  if (s.contains('e')) return s;
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Formats a value in engineering notation, e.g. `4.7 kΩ`, `100 nF`.
String formatSi(double v, String unit, {bool prefix = true, int sig = 4}) {
  if (!v.isFinite) return '—';
  if (!prefix || v == 0) return '${formatNumber(v, sig: sig)} $unit'.trim();
  var exp = ((log(v.abs()) / ln10) / 3).floor() * 3;
  exp = exp.clamp(-15, 12);
  var scaled = v / pow(10, exp);
  // Rounding can turn 999.96 into 1000; bump to the next prefix instead.
  if (double.parse(scaled.abs().toStringAsPrecision(sig)) >= 1000 && exp < 12) {
    exp += 3;
    scaled = v / pow(10, exp);
  }
  return '${formatNumber(scaled, sig: sig)} ${_formatPrefixes[exp]}$unit'.trim();
}

double radToDeg(double rad) => rad * 180 / pi;
