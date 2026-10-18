import 'dart:math';

import 'package:flutter/material.dart';

import 'core/calc.dart';
import 'core/eseries.dart';
import 'core/si.dart';
import 'screens/base_converter_screen.dart';
import 'screens/color_code_screen.dart';
import 'screens/linked_screen.dart';
import 'screens/motor_screen.dart';
import 'screens/ohm_screen.dart';
import 'screens/series_parallel_screen.dart';

class Cat {
  static const basics = 'Basics';
  static const parts = 'Components';
  static const ac = 'Filters & AC';
  static const timing = 'Timing & signals';
  static const power = 'Power';
  static const digital = 'Digital';
  static const motors = 'Motors & drivers';

  static const all = [basics, parts, ac, timing, power, motors, digital];
}

double _db20(double ratio) => 20 * log(ratio) / ln10;
double _db10(double ratio) => 10 * log(ratio) / ln10;
double? _positive(double v) => v > 0 ? v : null;

String _withError(double standard, double wanted, String unit) {
  final err = (standard - wanted) / wanted * 100;
  final sign = err >= 0 ? '+' : '';
  return '${formatSi(standard, unit)}  ($sign${err.toStringAsFixed(1)}%)';
}

String _duration(double hours) {
  if (hours < 1) return '${formatNumber(hours * 60, sig: 3)} min';
  if (hours < 48) return '${formatNumber(hours, sig: 3)} h';
  return '${formatNumber(hours, sig: 3)} h  (${formatNumber(hours / 24, sig: 3)} days)';
}

final List<CalcDef> calculators = [
  // ---------------------------------------------------------------- Basics
  CalcDef(
    id: 'ohm',
    title: "Ohm's law & power",
    category: Cat.basics,
    icon: Icons.bolt,
    formulas: const [
      'V = I × R',
      'P = V × I',
      'P = I² × R = V² / R',
    ],
    description: 'Fill in any two values and the other two get calculated.',
    tags: const ['voltage', 'current', 'resistance', 'power', 'watt', 'amp', 'volt'],
    screen: (calc) => OhmScreen(calc: calc),
  ),
  CalcDef(
    id: 'series_parallel',
    title: 'Series & parallel',
    category: Cat.basics,
    icon: Icons.account_tree_outlined,
    formulas: const ['Parallel R: 1/Rt = 1/R1 + 1/R2 + …'],
    tags: const ['resistor', 'capacitor', 'inductor', 'combine', 'total'],
    screen: (calc) => SeriesParallelScreen(calc: calc),
  ),
  CalcDef(
    id: 'divider',
    title: 'Voltage divider',
    category: Cat.basics,
    icon: Icons.call_split,
    formulas: const [
      'Vout = Vin × R2 / (R1 + R2)',
      'R2 = R1 × Vout / (Vin − Vout)',
    ],
    description:
        'R1 is the top resistor (to Vin), R2 is the bottom one (to ground). '
        'This assumes nothing is loading the output.',
    tags: const ['divider', 'resistor', 'ratio', 'bias'],
    inputs: const [
      InputField('vin', 'Input voltage Vin', 'V', hint: '12'),
      InputField('r1', 'R1 (top)', 'Ω', hint: '10k'),
      InputField('r2', 'R2 (bottom)', 'Ω', hint: '4.7k'),
      InputField('vt', 'Target Vout, to find R2', 'V', optional: true),
    ],
    outputs: [
      OutputField('Vout', 'V',
          needs: const ['vin', 'r1', 'r2'],
          compute: (v) => v['vin']! * v['r2']! / (v['r1']! + v['r2']!)),
      OutputField('Ratio Vout / Vin', '×',
          prefix: false,
          needs: const ['r1', 'r2'],
          compute: (v) => v['r2']! / (v['r1']! + v['r2']!)),
      OutputField('Current through divider', 'A',
          needs: const ['vin', 'r1', 'r2'],
          compute: (v) => v['vin']! / (v['r1']! + v['r2']!)),
      OutputField('R2 needed for target', 'Ω',
          needs: const ['vin', 'r1', 'vt'],
          compute: (v) => v['vt']! > 0 && v['vt']! < v['vin']!
              ? v['r1']! * v['vt']! / (v['vin']! - v['vt']!)
              : null),
      OutputField('Nearest E24 for R2', 'Ω',
          needs: const ['vin', 'r1', 'vt'],
          compute: (v) {
            final vt = v['vt']!, vin = v['vin']!;
            if (vt <= 0 || vt >= vin) return null;
            return eNearest(v['r1']! * vt / (vin - vt), e24);
          },
          format: (r, v) {
            final wanted = v['r1']! * v['vt']! / (v['vin']! - v['vt']!);
            return _withError(r, wanted, 'Ω');
          }),
    ],
  ),
  CalcDef(
    id: 'db',
    title: 'Decibels',
    category: Cat.basics,
    icon: Icons.graphic_eq,
    formulas: const [
      'Voltage: dB = 20 · log10(V2 / V1)',
      'Power:   dB = 10 · log10(P2 / P1)',
      '−3 dB ≈ 0.707× voltage ≈ ½ power',
      '+6 dB ≈ 2× voltage,  +20 dB = 10× voltage',
    ],
    description: 'Fill in only the pair you need. Each result works on its own.',
    tags: const ['decibel', 'gain', 'attenuation', 'log', 'ratio'],
    inputs: const [
      InputField('v2', 'Voltage out V2', 'V', optional: true),
      InputField('v1', 'Voltage in V1', 'V', optional: true),
      InputField('p2', 'Power out P2', 'W', optional: true),
      InputField('p1', 'Power in P1', 'W', optional: true),
      InputField('db', 'Decibels, to convert to a ratio', 'dB',
          optional: true, prefix: false),
    ],
    outputs: [
      OutputField('Voltage gain', 'dB',
          prefix: false,
          needs: const ['v2', 'v1'],
          compute: (v) => _db20(v['v2']! / v['v1']!)),
      OutputField('Power gain', 'dB',
          prefix: false,
          needs: const ['p2', 'p1'],
          compute: (v) => _db10(v['p2']! / v['p1']!)),
      OutputField('dB → voltage ratio', '×',
          prefix: false,
          needs: const ['db'],
          compute: (v) => pow(10, v['db']! / 20).toDouble()),
      OutputField('dB → power ratio', '×',
          prefix: false,
          needs: const ['db'],
          compute: (v) => pow(10, v['db']! / 10).toDouble()),
    ],
  ),
  CalcDef(
    id: 'dbm',
    title: 'dBm ↔ watts',
    category: Cat.basics,
    icon: Icons.settings_input_antenna,
    formulas: const [
      'dBm = 10 · log10(P / 1 mW)',
      'P = 1 mW · 10^(dBm / 10)',
      'Vrms = √(P · R)',
    ],
    description: '0 dBm = 1 mW, +30 dBm = 1 W.',
    tags: const ['rf', 'power', 'radio', 'dbm'],
    inputs: const [
      InputField('dbm', 'Power in dBm', 'dBm', optional: true, prefix: false),
      InputField('w', 'Power in watts', 'W', optional: true),
      InputField('r', 'Load impedance', 'Ω', hint: '50', optional: true),
    ],
    outputs: [
      OutputField('dBm → watts', 'W',
          needs: const ['dbm'],
          compute: (v) => 1e-3 * pow(10, v['dbm']! / 10)),
      OutputField('Watts → dBm', 'dBm',
          prefix: false,
          needs: const ['w'],
          compute: (v) => _positive(v['w']!) == null ? null : _db10(v['w']! / 1e-3)),
      OutputField('Vrms for dBm into load', 'V',
          needs: const ['dbm', 'r'],
          compute: (v) => sqrt(1e-3 * pow(10, v['dbm']! / 10) * v['r']!)),
    ],
  ),
  CalcDef(
    id: 'dbu',
    title: 'dBu · dBV ↔ volts',
    category: Cat.basics,
    icon: Icons.speaker,
    formulas: const [
      'dBu = 20 · log10(Vrms / 0.775 V)',
      'dBV = 20 · log10(Vrms / 1 V)',
      'Vrms = 0.775 V · 10^(dBu / 20)',
      'dBu = dBV + 2.21',
    ],
    description:
        'Audio levels. 0.775 V = √0.6, the voltage giving 1 mW into 600 Ω. '
        'Peak and peak-to-peak assume a sine wave.',
    tags: const ['dbu', 'dbv', 'audio', 'line level', 'volts', 'decibel', 'mixer'],
    screen: (calc) => LinkedConverterScreen(
      key: ValueKey(calc.id),
      calc: calc,
      config: LinkedConfig(
        fields: [
          LinkedField('dbu', 'dBu', 'dBu',
              prefix: false,
              hint: '+4',
              toBase: (v, _) => _dbuRef * pow(10, v / 20),
              fromBase: (b, _) => b > 0 ? _db20(b / _dbuRef) : null),
          LinkedField('dbv', 'dBV', 'dBV',
              prefix: false,
              hint: '-10',
              toBase: (v, _) => pow(10, v / 20).toDouble(),
              fromBase: (b, _) => b > 0 ? _db20(b) : null),
          LinkedField('rms', 'RMS', 'Vrms',
              toBase: (v, _) => v, fromBase: (b, _) => b),
          LinkedField('pk', 'Peak (sine)', 'Vpk',
              toBase: (v, _) => v / sqrt2, fromBase: (b, _) => b * sqrt2),
          LinkedField('pp', 'Peak-to-peak (sine)', 'Vpp',
              toBase: (v, _) => v / (2 * sqrt2), fromBase: (b, _) => b * 2 * sqrt2),
        ],
        factsTitle: 'Reference levels',
        facts: (_) => const [
          ('+4 dBu  pro line level', '1.228 Vrms'),
          ('−10 dBV  consumer line level', '0.316 Vrms'),
          ('0 dBu', '0.775 Vrms'),
          ('0 dBV', '1 Vrms'),
          ('+4 dBu vs −10 dBV', '≈ 11.8 dB apart'),
        ],
      ),
    ),
  ),

  // ------------------------------------------------------------ Components
  CalcDef(
    id: 'color_code',
    title: 'Resistor color code',
    category: Cat.parts,
    icon: Icons.palette_outlined,
    formulas: const [
      'Bands: digit · digit (· digit) · multiplier · tolerance',
      'Black 0 · Brown 1 · Red 2 · Orange 3 · Yellow 4',
      'Green 5 · Blue 6 · Violet 7 · Grey 8 · White 9',
      'Gold ×0.1 / ±5% · Silver ×0.01 / ±10%',
    ],
    description: 'Tap the colors, or type a value to see which bands it has.',
    tags: const ['resistor', 'bands', 'colour', 'color'],
    screen: (calc) => ColorCodeScreen(calc: calc),
  ),
  CalcDef(
    id: 'led',
    title: 'LED resistor',
    category: Cat.parts,
    icon: Icons.lightbulb_outline,
    formulas: const [
      'R = (Vs − n · Vf) / I',
      'P(R) = (Vs − n · Vf) × I',
    ],
    description:
        'Typical Vf: red/yellow ≈ 2 V, green ≈ 2.2–3 V, blue/white ≈ 3 V. '
        'Typical current: 5–20 mA. Round the resistor UP, not down.',
    tags: const ['led', 'diode', 'resistor', 'current limiting'],
    inputs: const [
      InputField('vs', 'Supply voltage Vs', 'V', hint: '5'),
      InputField('vf', 'LED forward voltage Vf', 'V', hint: '2'),
      InputField('i', 'LED current', 'A', hint: '10m'),
      InputField('n', 'LEDs in series', '', hint: '1', optional: true, prefix: false),
    ],
    outputs: [
      OutputField('Resistor', 'Ω',
          needs: const ['vs', 'vf', 'i'],
          compute: (v) {
            final drop = v['vs']! - (v['n'] ?? 1) * v['vf']!;
            return drop > 0 && v['i']! > 0 ? drop / v['i']! : null;
          }),
      OutputField('Next E12 value up', 'Ω',
          needs: const ['vs', 'vf', 'i'],
          compute: (v) {
            final drop = v['vs']! - (v['n'] ?? 1) * v['vf']!;
            return drop > 0 && v['i']! > 0 ? eNextUp(drop / v['i']!, e12) : null;
          }),
      OutputField('Power in resistor', 'W',
          needs: const ['vs', 'vf', 'i'],
          compute: (v) {
            final drop = v['vs']! - (v['n'] ?? 1) * v['vf']!;
            return drop > 0 ? drop * v['i']! : null;
          },
          format: (p, _) {
            final rating = [0.125, 0.25, 0.5, 1.0, 2.0, 5.0]
                .firstWhere((r) => r >= p * 2, orElse: () => double.nan);
            final pick = rating.isNaN ? 'use a big one!' : 'use ≥ ${formatNumber(rating)} W';
            return '${formatSi(p, 'W')}  ($pick)';
          }),
    ],
  ),
  CalcDef(
    id: 'parallel_find',
    title: 'Find the missing parallel resistor',
    category: Cat.parts,
    icon: Icons.search,
    formulas: const [
      'R2 = R1 · Rt / (R1 − Rt)',
      'Only works if R1 > Rt',
    ],
    description:
        'You want a total value Rt and already have R1. Which R2 do you put in parallel?',
    tags: const ['parallel', 'resistor', 'target'],
    inputs: const [
      InputField('rt', 'Target total Rt', 'Ω', hint: '3.3k'),
      InputField('r1', 'Resistor you have R1', 'Ω', hint: '4.7k'),
    ],
    outputs: [
      OutputField('R2 needed', 'Ω',
          needs: const ['rt', 'r1'],
          compute: (v) => v['r1']! > v['rt']!
              ? v['r1']! * v['rt']! / (v['r1']! - v['rt']!)
              : null),
      OutputField('Nearest E24', 'Ω',
          needs: const ['rt', 'r1'],
          compute: (v) => v['r1']! > v['rt']!
              ? eNearest(v['r1']! * v['rt']! / (v['r1']! - v['rt']!), e24)
              : null,
          format: (r, v) =>
              _withError(r, v['r1']! * v['rt']! / (v['r1']! - v['rt']!), 'Ω')),
    ],
  ),
  CalcDef(
    id: 'eseries',
    title: 'Standard values (E-series)',
    category: Cat.parts,
    icon: Icons.format_list_numbered,
    formulas: const [
      'E12: 1.0 1.2 1.5 1.8 2.2 2.7 3.3 3.9 4.7 5.6 6.8 8.2',
      'E6:  1.0 1.5 2.2 3.3 4.7 6.8',
    ],
    description:
        'Snaps a calculated value to a part you can actually buy. '
        'E12 ≈ 10% parts, E24 ≈ 5%, E96 ≈ 1%. Works for R, C, L.',
    tags: const ['e12', 'e24', 'e96', 'standard', 'nearest', 'resistor', 'capacitor'],
    inputs: const [
      InputField('x', 'Value', '', hint: '5.1k'),
    ],
    outputs: [
      for (final (name, series) in [('E6', e6), ('E12', e12), ('E24', e24), ('E96', e96)])
        OutputField('Nearest $name', '',
            needs: const ['x'],
            compute: (v) => eNearest(v['x']!, series),
            format: (r, v) => _withError(r, v['x']!, '')),
    ],
  ),
  CalcDef(
    id: 'energy',
    title: 'Stored energy (C & L)',
    category: Cat.parts,
    icon: Icons.battery_charging_full,
    formulas: const [
      'Q = C × V',
      'E(C) = ½ · C · V²',
      'E(L) = ½ · L · I²',
    ],
    tags: const ['capacitor', 'inductor', 'joule', 'charge', 'coulomb'],
    inputs: const [
      InputField('c', 'Capacitance C', 'F', hint: '100u', optional: true),
      InputField('v', 'Voltage on capacitor', 'V', optional: true),
      InputField('l', 'Inductance L', 'H', optional: true),
      InputField('i', 'Current through inductor', 'A', optional: true),
    ],
    outputs: [
      OutputField('Charge Q', 'C',
          needs: const ['c', 'v'], compute: (v) => v['c']! * v['v']!),
      OutputField('Energy in capacitor', 'J',
          needs: const ['c', 'v'], compute: (v) => 0.5 * v['c']! * v['v']! * v['v']!),
      OutputField('Energy in inductor', 'J',
          needs: const ['l', 'i'], compute: (v) => 0.5 * v['l']! * v['i']! * v['i']!),
    ],
  ),

  // ---------------------------------------------------------- Filters & AC
  CalcDef(
    id: 'rc_lowpass',
    title: 'RC low-pass filter',
    category: Cat.ac,
    icon: Icons.trending_down,
    formulas: const [
      'fc = 1 / (2π · R · C)',
      '|H| = 1 / √(1 + (f / fc)²)',
      'φ = −atan(f / fc)',
    ],
    description:
        'Lets low frequencies through. At fc the output is −3 dB (≈70.7%), '
        'then it falls by 20 dB per decade.',
    tags: const ['filter', 'lowpass', 'cutoff', 'corner', 'rc'],
    inputs: const [
      InputField('r', 'Resistance R', 'Ω', hint: '10k'),
      InputField('c', 'Capacitance C', 'F', hint: '100n'),
      InputField('f', 'Check at frequency f', 'Hz', optional: true),
    ],
    outputs: [
      OutputField('Cutoff frequency fc', 'Hz',
          needs: const ['r', 'c'], compute: (v) => 1 / (2 * pi * v['r']! * v['c']!)),
      OutputField('Time constant τ', 's',
          needs: const ['r', 'c'], compute: (v) => v['r']! * v['c']!),
      OutputField('Gain at f', 'dB',
          prefix: false,
          needs: const ['r', 'c', 'f'],
          compute: (v) {
            final x = v['f']! * 2 * pi * v['r']! * v['c']!;
            return _db20(1 / sqrt(1 + x * x));
          }),
      OutputField('Output at f', '% of input',
          prefix: false,
          needs: const ['r', 'c', 'f'],
          compute: (v) {
            final x = v['f']! * 2 * pi * v['r']! * v['c']!;
            return 100 / sqrt(1 + x * x);
          }),
      OutputField('Phase at f', '°',
          prefix: false,
          needs: const ['r', 'c', 'f'],
          compute: (v) => -radToDeg(atan(v['f']! * 2 * pi * v['r']! * v['c']!))),
    ],
  ),
  CalcDef(
    id: 'rc_highpass',
    title: 'RC high-pass filter',
    category: Cat.ac,
    icon: Icons.trending_up,
    formulas: const [
      'fc = 1 / (2π · R · C)',
      '|H| = (f/fc) / √(1 + (f/fc)²)',
      'φ = 90° − atan(f / fc)',
    ],
    description:
        'Lets high frequencies through and blocks DC. At fc the output is −3 dB (≈70.7%).',
    tags: const ['filter', 'highpass', 'cutoff', 'corner', 'rc', 'dc blocking'],
    inputs: const [
      InputField('r', 'Resistance R', 'Ω', hint: '10k'),
      InputField('c', 'Capacitance C', 'F', hint: '100n'),
      InputField('f', 'Check at frequency f', 'Hz', optional: true),
    ],
    outputs: [
      OutputField('Cutoff frequency fc', 'Hz',
          needs: const ['r', 'c'], compute: (v) => 1 / (2 * pi * v['r']! * v['c']!)),
      OutputField('Time constant τ', 's',
          needs: const ['r', 'c'], compute: (v) => v['r']! * v['c']!),
      OutputField('Gain at f', 'dB',
          prefix: false,
          needs: const ['r', 'c', 'f'],
          compute: (v) {
            final x = v['f']! * 2 * pi * v['r']! * v['c']!;
            return _db20(x / sqrt(1 + x * x));
          }),
      OutputField('Output at f', '% of input',
          prefix: false,
          needs: const ['r', 'c', 'f'],
          compute: (v) {
            final x = v['f']! * 2 * pi * v['r']! * v['c']!;
            return 100 * x / sqrt(1 + x * x);
          }),
      OutputField('Phase at f', '°',
          prefix: false,
          needs: const ['r', 'c', 'f'],
          compute: (v) => 90 - radToDeg(atan(v['f']! * 2 * pi * v['r']! * v['c']!))),
    ],
  ),
  CalcDef(
    id: 'rc_design',
    title: 'RC filter design (find R or C)',
    category: Cat.ac,
    icon: Icons.design_services_outlined,
    formulas: const [
      'C = 1 / (2π · fc · R)',
      'R = 1 / (2π · fc · C)',
    ],
    description:
        'Know the cutoff you want? Fill in fc and either R or C. Same for low-pass and high-pass.',
    tags: const ['filter', 'design', 'cutoff', 'lowpass', 'highpass'],
    inputs: const [
      InputField('fc', 'Wanted cutoff fc', 'Hz', hint: '1k'),
      InputField('r', 'Resistor you picked R', 'Ω', optional: true),
      InputField('c', 'Capacitor you picked C', 'F', optional: true),
    ],
    outputs: [
      OutputField('C needed', 'F',
          needs: const ['fc', 'r'], compute: (v) => 1 / (2 * pi * v['fc']! * v['r']!)),
      OutputField('Nearest E12 C', 'F',
          needs: const ['fc', 'r'],
          compute: (v) => eNearest(1 / (2 * pi * v['fc']! * v['r']!), e12),
          format: (c, v) => _withError(c, 1 / (2 * pi * v['fc']! * v['r']!), 'F')),
      OutputField('R needed', 'Ω',
          needs: const ['fc', 'c'], compute: (v) => 1 / (2 * pi * v['fc']! * v['c']!)),
      OutputField('Nearest E24 R', 'Ω',
          needs: const ['fc', 'c'],
          compute: (v) => eNearest(1 / (2 * pi * v['fc']! * v['c']!), e24),
          format: (r, v) => _withError(r, 1 / (2 * pi * v['fc']! * v['c']!), 'Ω')),
    ],
  ),
  CalcDef(
    id: 'rl_filter',
    title: 'RL filter',
    category: Cat.ac,
    icon: Icons.waves,
    formulas: const [
      'fc = R / (2π · L)',
      'τ = L / R',
    ],
    description:
        'Low-pass: L in series, R to ground. High-pass: R in series, L to ground.',
    tags: const ['filter', 'inductor', 'cutoff', 'lowpass', 'highpass'],
    inputs: const [
      InputField('r', 'Resistance R', 'Ω', hint: '100'),
      InputField('l', 'Inductance L', 'H', hint: '10m'),
      InputField('f', 'Check at frequency f', 'Hz', optional: true),
    ],
    outputs: [
      OutputField('Cutoff frequency fc', 'Hz',
          needs: const ['r', 'l'], compute: (v) => v['r']! / (2 * pi * v['l']!)),
      OutputField('Time constant τ', 's',
          needs: const ['r', 'l'], compute: (v) => v['l']! / v['r']!),
      OutputField('Low-pass gain at f', 'dB',
          prefix: false,
          needs: const ['r', 'l', 'f'],
          compute: (v) {
            final x = v['f']! * 2 * pi * v['l']! / v['r']!;
            return _db20(1 / sqrt(1 + x * x));
          }),
      OutputField('High-pass gain at f', 'dB',
          prefix: false,
          needs: const ['r', 'l', 'f'],
          compute: (v) {
            final x = v['f']! * 2 * pi * v['l']! / v['r']!;
            return _db20(x / sqrt(1 + x * x));
          }),
    ],
  ),
  CalcDef(
    id: 'reactance',
    title: 'Reactance (Xc, XL)',
    category: Cat.ac,
    icon: Icons.swap_vert,
    formulas: const [
      'Xc = 1 / (2π · f · C)',
      'XL = 2π · f · L',
    ],
    description: 'A capacitor resists less at high frequency, an inductor resists more.',
    tags: const ['reactance', 'capacitor', 'inductor', 'ac', 'impedance'],
    inputs: const [
      InputField('f', 'Frequency f', 'Hz', hint: '1k'),
      InputField('c', 'Capacitance C', 'F', optional: true),
      InputField('l', 'Inductance L', 'H', optional: true),
    ],
    outputs: [
      OutputField('Capacitive reactance Xc', 'Ω',
          needs: const ['f', 'c'], compute: (v) => 1 / (2 * pi * v['f']! * v['c']!)),
      OutputField('Inductive reactance XL', 'Ω',
          needs: const ['f', 'l'], compute: (v) => 2 * pi * v['f']! * v['l']!),
      OutputField('Angular frequency ω', 'rad/s',
          needs: const ['f'], compute: (v) => 2 * pi * v['f']!),
    ],
  ),
  CalcDef(
    id: 'impedance',
    title: 'Impedance (RLC)',
    category: Cat.ac,
    icon: Icons.blur_circular,
    formulas: const [
      'X = XL − Xc',
      'Series:   |Z| = √(R² + X²)',
      'Parallel: |Z| = 1 / √((1/R)² + (ωC − 1/ωL)²)',
      'φ = atan(X / R)',
    ],
    description:
        'Leave out the parts you don\'t have. Positive phase means inductive '
        '(current lags), negative means capacitive (current leads).',
    tags: const ['impedance', 'rlc', 'phase', 'ac', 'reactance'],
    inputs: const [
      InputField('f', 'Frequency f', 'Hz', hint: '1k'),
      InputField('r', 'Resistance R', 'Ω', optional: true),
      InputField('l', 'Inductance L', 'H', optional: true),
      InputField('c', 'Capacitance C', 'F', optional: true),
    ],
    outputs: [
      OutputField('Series: net reactance X', 'Ω',
          needs: const ['f'], compute: (v) => _seriesX(v)),
      OutputField('Series: |Z|', 'Ω',
          needs: const ['f'],
          compute: (v) {
            final x = _seriesX(v), r = v['r'] ?? 0;
            return x == null && v['r'] == null ? null : sqrt(r * r + (x ?? 0) * (x ?? 0));
          }),
      OutputField('Series: phase', '°',
          prefix: false,
          needs: const ['f'],
          compute: (v) {
            final x = _seriesX(v) ?? 0, r = v['r'] ?? 0;
            return x == 0 && r == 0 ? null : radToDeg(atan2(x, r));
          }),
      OutputField('Parallel: |Z|', 'Ω',
          needs: const ['f'],
          compute: (v) {
            final (g, b) = _parallelGB(v);
            return g == 0 && b == 0 ? null : 1 / sqrt(g * g + b * b);
          }),
      OutputField('Parallel: phase', '°',
          prefix: false,
          needs: const ['f'],
          compute: (v) {
            final (g, b) = _parallelGB(v);
            return g == 0 && b == 0 ? null : radToDeg(-atan2(b, g));
          }),
    ],
  ),
  CalcDef(
    id: 'lc_resonance',
    title: 'LC resonance',
    category: Cat.ac,
    icon: Icons.radio,
    formulas: const [
      'f0 = 1 / (2π · √(L · C))',
      'Z0 = √(L / C)',
      'Q (series) = Z0 / R,   BW = f0 / Q',
    ],
    description: 'Add R (series resistance) to get Q and bandwidth.',
    tags: const ['resonance', 'tank', 'lc', 'q factor', 'bandwidth', 'oscillator'],
    inputs: const [
      InputField('l', 'Inductance L', 'H', hint: '10u'),
      InputField('c', 'Capacitance C', 'F', hint: '100p'),
      InputField('r', 'Series resistance R', 'Ω', optional: true),
    ],
    outputs: [
      OutputField('Resonant frequency f0', 'Hz',
          needs: const ['l', 'c'], compute: (v) => 1 / (2 * pi * sqrt(v['l']! * v['c']!))),
      OutputField('Characteristic impedance Z0', 'Ω',
          needs: const ['l', 'c'], compute: (v) => sqrt(v['l']! / v['c']!)),
      OutputField('Quality factor Q', '',
          prefix: false,
          needs: const ['l', 'c', 'r'],
          compute: (v) => sqrt(v['l']! / v['c']!) / v['r']!),
      OutputField('Bandwidth (−3 dB)', 'Hz',
          needs: const ['l', 'c', 'r'],
          compute: (v) => v['r']! / (2 * pi * v['l']!)),
    ],
  ),
  CalcDef(
    id: 'opamp',
    title: 'Op-amp gain',
    category: Cat.ac,
    icon: Icons.change_history,
    formulas: const [
      'Inverting:      G = −Rf / Rin',
      'Non-inverting:  G = 1 + Rf / Rg',
      'Vout = G × Vin',
    ],
    description:
        'Rf is the feedback resistor (output → − input). Rin/Rg goes from the − input '
        'to the signal (inverting) or to ground (non-inverting).',
    tags: const ['opamp', 'amplifier', 'gain', 'inverting', 'non-inverting'],
    inputs: const [
      InputField('rf', 'Feedback resistor Rf', 'Ω', hint: '100k'),
      InputField('rin', 'Rin / Rg', 'Ω', hint: '10k'),
      InputField('vin', 'Input voltage', 'V', optional: true),
    ],
    outputs: [
      OutputField('Inverting gain', '×',
          prefix: false,
          needs: const ['rf', 'rin'],
          compute: (v) => -v['rf']! / v['rin']!,
          format: (g, _) => '${formatNumber(g)}×  (${formatNumber(_db20(g.abs()), sig: 3)} dB)'),
      OutputField('Non-inverting gain', '×',
          prefix: false,
          needs: const ['rf', 'rin'],
          compute: (v) => 1 + v['rf']! / v['rin']!,
          format: (g, _) => '${formatNumber(g)}×  (${formatNumber(_db20(g), sig: 3)} dB)'),
      OutputField('Vout, inverting', 'V',
          needs: const ['rf', 'rin', 'vin'],
          compute: (v) => -v['rf']! / v['rin']! * v['vin']!),
      OutputField('Vout, non-inverting', 'V',
          needs: const ['rf', 'rin', 'vin'],
          compute: (v) => (1 + v['rf']! / v['rin']!) * v['vin']!),
    ],
  ),

  // ------------------------------------------------------ Timing & signals
  CalcDef(
    id: 'rc_tau',
    title: 'RC time constant (τ)',
    category: Cat.timing,
    icon: Icons.timer_outlined,
    formulas: const [
      'τ = R × C',
      'Charging:    Vc = Vs · (1 − e^(−t/τ))',
      'Discharging: Vc = V0 · e^(−t/τ)',
      'Time to V:   t = −τ · ln(1 − V / Vs)',
      '1τ → 63%,  3τ → 95%,  5τ → 99.3%',
    ],
    tags: const ['tau', 'time constant', 'charge', 'discharge', 'capacitor', 'rc', 'delay'],
    inputs: const [
      InputField('r', 'Resistance R', 'Ω', hint: '10k'),
      InputField('c', 'Capacitance C', 'F', hint: '100u'),
      InputField('vs', 'Supply voltage Vs', 'V', optional: true),
      InputField('t', 'At time t', 's', optional: true),
      InputField('vt', 'Time to reach voltage', 'V', optional: true),
    ],
    outputs: [
      OutputField('τ (63% charged)', 's',
          needs: const ['r', 'c'], compute: (v) => v['r']! * v['c']!),
      OutputField('5τ (fully charged)', 's',
          needs: const ['r', 'c'], compute: (v) => 5 * v['r']! * v['c']!),
      OutputField('Charged at t', '%',
          prefix: false,
          needs: const ['r', 'c', 't'],
          compute: (v) => 100 * (1 - exp(-v['t']! / (v['r']! * v['c']!)))),
      OutputField('Vc at t (charging)', 'V',
          needs: const ['r', 'c', 't', 'vs'],
          compute: (v) => v['vs']! * (1 - exp(-v['t']! / (v['r']! * v['c']!)))),
      OutputField('Vc at t (discharging from Vs)', 'V',
          needs: const ['r', 'c', 't', 'vs'],
          compute: (v) => v['vs']! * exp(-v['t']! / (v['r']! * v['c']!))),
      OutputField('Time to charge to voltage', 's',
          needs: const ['r', 'c', 'vs', 'vt'],
          compute: (v) {
            final ratio = v['vt']! / v['vs']!;
            return ratio > 0 && ratio < 1
                ? -v['r']! * v['c']! * log(1 - ratio)
                : null;
          }),
    ],
  ),
  CalcDef(
    id: '555_astable',
    title: '555 timer (astable)',
    category: Cat.timing,
    icon: Icons.av_timer,
    formulas: const [
      'f = 1.44 / ((R1 + 2·R2) · C)',
      't_high = 0.693 · (R1 + R2) · C',
      't_low  = 0.693 · R2 · C',
    ],
    description:
        'Free-running oscillator / blinker. R1: pin 7 to Vcc, R2: pin 7 to pins 2+6, '
        'C: pins 2+6 to ground. Duty is always above 50% in this circuit.',
    tags: const ['555', 'ne555', 'oscillator', 'blinker', 'timer', 'pwm', 'astable'],
    inputs: const [
      InputField('r1', 'R1', 'Ω', hint: '1k'),
      InputField('r2', 'R2', 'Ω', hint: '10k'),
      InputField('c', 'C', 'F', hint: '10u'),
    ],
    outputs: [
      OutputField('Frequency', 'Hz',
          needs: const ['r1', 'r2', 'c'],
          compute: (v) => 1.44 / ((v['r1']! + 2 * v['r2']!) * v['c']!)),
      OutputField('Period', 's',
          needs: const ['r1', 'r2', 'c'],
          compute: (v) => 0.693 * (v['r1']! + 2 * v['r2']!) * v['c']!),
      OutputField('High time', 's',
          needs: const ['r1', 'r2', 'c'],
          compute: (v) => 0.693 * (v['r1']! + v['r2']!) * v['c']!),
      OutputField('Low time', 's',
          needs: const ['r2', 'c'], compute: (v) => 0.693 * v['r2']! * v['c']!),
      OutputField('Duty cycle', '%',
          prefix: false,
          needs: const ['r1', 'r2'],
          compute: (v) =>
              100 * (v['r1']! + v['r2']!) / (v['r1']! + 2 * v['r2']!)),
    ],
  ),
  CalcDef(
    id: '555_mono',
    title: '555 timer (one-shot)',
    category: Cat.timing,
    icon: Icons.hourglass_bottom,
    formulas: const ['t = 1.1 · R · C'],
    description: 'Monostable: one pulse of length t after a trigger on pin 2.',
    tags: const ['555', 'ne555', 'monostable', 'one shot', 'pulse', 'delay', 'timer'],
    inputs: const [
      InputField('r', 'R', 'Ω', hint: '100k'),
      InputField('c', 'C', 'F', hint: '10u'),
      InputField('t', 'Wanted time, to find R', 's', optional: true),
    ],
    outputs: [
      OutputField('Pulse length', 's',
          needs: const ['r', 'c'], compute: (v) => 1.1 * v['r']! * v['c']!),
      OutputField('R needed for wanted time', 'Ω',
          needs: const ['c', 't'], compute: (v) => v['t']! / (1.1 * v['c']!)),
    ],
  ),
  CalcDef(
    id: 'freq',
    title: 'Time ↔ frequency',
    category: Cat.timing,
    icon: Icons.ssid_chart,
    formulas: const [
      'f = 1 / T     T = 1 / f',
      'ω = 2π · f',
      'per minute = f × 60',
      'λ = c · VF / f,   c ≈ 3×10⁸ m/s',
    ],
    description:
        'Period, frequency, ω, RPM/BPM and wavelength. The switch sets the velocity '
        'factor VF for wavelength only: air 1, typical coax 0.66, FR4 PCB ≈ 0.5.',
    tags: const ['time', 'frequency', 'period', 'hz', 'ms', 'wavelength', 'antenna',
        'omega', 'rf', 'rpm', 'bpm', 'clock', 'convert'],
    screen: (calc) => LinkedConverterScreen(
      key: ValueKey(calc.id),
      calc: calc,
      config: LinkedConfig(
        modes: const ['Air', 'Coax 0.66', 'PCB 0.5'],
        fields: [
          LinkedField('t', 'Period T', 's',
              hint: '20m', toBase: (v, _) => 1 / v, fromBase: (f, _) => 1 / f),
          LinkedField('f', 'Frequency f', 'Hz',
              hint: '50', toBase: (v, _) => v, fromBase: (f, _) => f),
          LinkedField('w', 'Angular frequency ω', 'rad/s',
              toBase: (v, _) => v / (2 * pi), fromBase: (f, _) => f * 2 * pi),
          LinkedField('min', 'Per minute (RPM, BPM)', '/min',
              prefix: false, toBase: (v, _) => v / 60, fromBase: (f, _) => f * 60),
          LinkedField('l', 'Wavelength λ', 'm',
              toBase: (v, m) => _c0 * _vf(m) / v, fromBase: (f, m) => _c0 * _vf(m) / f),
          LinkedField('l4', 'Quarter wave λ/4', 'm',
              toBase: (v, m) => _c0 * _vf(m) / (4 * v),
              fromBase: (f, m) => _c0 * _vf(m) / (4 * f)),
        ],
        factsTitle: 'Worth remembering',
        facts: (_) => const [
          ('1 kHz', '1 ms'),
          ('1 MHz', '1 µs'),
          ('50 Hz mains', '20 ms'),
          ('60 Hz mains', '16.67 ms'),
          ('60 BPM', '1 Hz'),
        ],
      ),
    ),
  ),
  CalcDef(
    id: 'rms',
    title: 'RMS · peak · peak-to-peak · average',
    category: Cat.timing,
    icon: Icons.show_chart,
    formulas: _rmsFormulas('Sine'),
    description:
        'For a wave centered on 0 V (no DC offset). Works for current too. '
        'Average = rectified average, what a cheap (non true-RMS) meter really measures.',
    tags: const ['rms', 'peak', 'pp', 'peak to peak', 'average', 'mean', 'sine', 'square', 'triangle', 'waveform', 'ac'],
    screen: (calc) => LinkedConverterScreen(
      key: ValueKey(calc.id),
      calc: calc,
      config: LinkedConfig(
        modes: const ['Sine', 'Square', 'Triangle', 'Saw'],
        formulasFor: _rmsFormulas,
        fields: [
          LinkedField('pk', 'Peak', 'Vpk',
              hint: '1', toBase: (v, _) => v, fromBase: (b, _) => b),
          LinkedField('pp', 'Peak-to-peak', 'Vpp',
              toBase: (v, _) => v / 2, fromBase: (b, _) => b * 2),
          LinkedField('rms', 'RMS', 'Vrms',
              toBase: (v, m) => v / _rmsFactor(m), fromBase: (b, m) => b * _rmsFactor(m)),
          LinkedField('avg', 'Average (rectified)', 'Vavg',
              toBase: (v, m) => v / _avgFactor(m), fromBase: (b, m) => b * _avgFactor(m)),
        ],
        factsTitle: 'Waveform factors',
        facts: (m) => [
          ('Crest factor  peak / RMS', formatNumber(1 / _rmsFactor(m))),
          ('Form factor  RMS / average', formatNumber(_rmsFactor(m) / _avgFactor(m))),
        ],
      ),
    ),
  ),

  // ------------------------------------------------------------------ Power
  CalcDef(
    id: 'linreg',
    title: 'Linear regulator heat',
    category: Cat.power,
    icon: Icons.local_fire_department_outlined,
    formulas: const [
      'P = (Vin − Vout) × I',
      'Efficiency = Vout / Vin',
      'T_junction = T_ambient + P × θJA',
    ],
    description:
        'For 7805, LM317, LDOs, Zener regulators… θJA is in the datasheet '
        '(TO-220 without heatsink ≈ 50–65 °C/W).',
    tags: const ['regulator', 'ldo', '7805', 'lm317', 'heat', 'dissipation', 'zener'],
    inputs: const [
      InputField('vin', 'Input voltage', 'V', hint: '12'),
      InputField('vout', 'Output voltage', 'V', hint: '5'),
      InputField('i', 'Load current', 'A', hint: '500m'),
      InputField('theta', 'θJA', '°C/W', hint: '50', optional: true, prefix: false),
      InputField('ta', 'Ambient temperature', '°C', hint: '25', optional: true, prefix: false),
    ],
    outputs: [
      OutputField('Heat in regulator', 'W',
          needs: const ['vin', 'vout', 'i'],
          compute: (v) => v['vin']! >= v['vout']!
              ? (v['vin']! - v['vout']!) * v['i']!
              : null),
      OutputField('Efficiency', '%',
          prefix: false,
          needs: const ['vin', 'vout'],
          compute: (v) => v['vin']! > 0 ? 100 * v['vout']! / v['vin']! : null),
      OutputField('Junction temperature', '°C',
          prefix: false,
          needs: const ['vin', 'vout', 'i', 'theta'],
          compute: (v) =>
              (v['ta'] ?? 25) + (v['vin']! - v['vout']!) * v['i']! * v['theta']!,
          format: (t, _) =>
              '${formatNumber(t, sig: 3)} °C${t > 125 ? '  — too hot' : ''}'),
    ],
  ),
  CalcDef(
    id: 'battery',
    title: 'Battery life',
    category: Cat.power,
    icon: Icons.battery_std,
    formulas: const [
      'Runtime = Capacity / Current',
      'Realistic ≈ × 0.7–0.8',
    ],
    description: 'Type the capacity like 2000m for 2000 mAh.',
    tags: const ['battery', 'mah', 'runtime', 'lipo', 'capacity'],
    inputs: const [
      InputField('cap', 'Capacity', 'Ah', hint: '2000m'),
      InputField('i', 'Average current', 'A', hint: '50m'),
      InputField('eff', 'Usable capacity', '%', hint: '80', optional: true, prefix: false),
    ],
    outputs: [
      OutputField('Runtime (ideal)', 'h',
          needs: const ['cap', 'i'],
          compute: (v) => _positive(v['i']!) == null ? null : v['cap']! / v['i']!,
          format: (h, _) => _duration(h)),
      OutputField('Runtime (realistic)', 'h',
          needs: const ['cap', 'i'],
          compute: (v) => _positive(v['i']!) == null
              ? null
              : v['cap']! / v['i']! * (v['eff'] ?? 80) / 100,
          format: (h, _) => _duration(h)),
    ],
  ),

  // ------------------------------------------------------- Motors & drivers
  CalcDef(
    id: 'motor',
    title: 'Motor constants (DRV8234)',
    category: Cat.motors,
    icon: Icons.settings,
    formulas: const [
      'RPM = Hz × 60      Kv = RPM / V',
      'ω = 2π · Hz        Ke = V / ω',
      'Ke(IR) = (V − I·R) / ω',
      'INV_R = round(INV_R_SCALE / R)',
      'KMC = round(Ke / NR × KMC_SCALE)',
      'WSET_VSET = round(RPM·NR·2π/60 / W_SCALE)',
    ],
    description:
        'Run the motor with no load at a realistic voltage. Measure the shaft speed (Hz) '
        'and the bench supply current, then fill them in.',
    tags: const ['motor', 'kv', 'ke', 'back emf', 'rpm', 'drv8234', 'ripple', 'register',
        'inv_r', 'kmc', 'wset', 'dc motor'],
    screen: (calc) => MotorScreen(calc: calc),
  ),

  // ---------------------------------------------------------------- Digital
  CalcDef(
    id: 'base_convert',
    title: 'Hex · decimal · binary · ASCII',
    category: Cat.digital,
    icon: Icons.tag,
    formulas: const [
      '1 hex digit = 4 bits,  2 hex digits = 1 byte',
      "'0' = 0x30 = 48    'A' = 0x41 = 65",
      "' ' = 0x20 = 32    'a' = 0x61 = 97",
      'lowercase = uppercase + 0x20',
    ],
    description:
        'Type in any field and the others follow. Several bytes work too: '
        '"Hi" = 48 69. Negative decimals become two\'s complement (−1 = FF).',
    tags: const ['hex', 'hexadecimal', 'decimal', 'binary', 'ascii', 'octal', 'base', 'convert', 'char'],
    screen: (calc) => BaseConverterScreen(calc: calc),
  ),
];

const _dbuRef = 0.7745966692414834; // √0.6 V
const _c0 = 299792458.0; // speed of light, m/s

double _vf(String medium) => switch (medium) {
      'Coax 0.66' => 0.66,
      'PCB 0.5' => 0.5,
      _ => 1.0,
    };

double _rmsFactor(String wave) => switch (wave) {
      'Sine' => 1 / sqrt2,
      'Square' => 1.0,
      _ => 1 / sqrt(3), // triangle and sawtooth
    };

double _avgFactor(String wave) => switch (wave) {
      'Sine' => 2 / pi,
      'Square' => 1.0,
      _ => 0.5,
    };

List<String> _rmsFormulas(String wave) => [
      'Vpp = 2 · Vpeak',
      ...switch (wave) {
        'Sine' => ['Vrms = Vpeak / √2 ≈ 0.707 · Vpeak', 'Vavg = 2 · Vpeak / π ≈ 0.637 · Vpeak'],
        'Square' => ['Vrms = Vpeak', 'Vavg = Vpeak'],
        _ => ['Vrms = Vpeak / √3 ≈ 0.577 · Vpeak', 'Vavg = Vpeak / 2'],
      },
    ];

double? _seriesX(Map<String, double> v) {
  final w = 2 * pi * v['f']!;
  final l = v['l'], c = v['c'];
  if (l == null && c == null) return null;
  return (l != null ? w * l : 0) - (c != null ? 1 / (w * c) : 0);
}

(double, double) _parallelGB(Map<String, double> v) {
  final w = 2 * pi * v['f']!;
  final r = v['r'], l = v['l'], c = v['c'];
  final g = r != null ? 1 / r : 0.0;
  final b = (c != null ? w * c : 0.0) - (l != null ? 1 / (w * l) : 0.0);
  return (g, b);
}

CalcDef calcById(String id) => calculators.firstWhere((c) => c.id == id);
