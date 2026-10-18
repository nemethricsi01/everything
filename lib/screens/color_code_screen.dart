import 'dart:math';

import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/si.dart';
import '../theme.dart';
import '../widgets/common.dart';

class BandColor {
  const BandColor(this.name, this.color,
      {this.digit, required this.exponent, this.tolerance});

  final String name;
  final Color color;
  final int? digit;

  /// Multiplier as a power of ten (gold = −1, silver = −2).
  final int exponent;
  final double? tolerance;
}

const bandColors = [
  BandColor('Black', Color(0xFF000000), digit: 0, exponent: 0),
  BandColor('Brown', Color(0xFF795548), digit: 1, exponent: 1, tolerance: 1),
  BandColor('Red', Color(0xFFE53935), digit: 2, exponent: 2, tolerance: 2),
  BandColor('Orange', Color(0xFFFB8C00), digit: 3, exponent: 3),
  BandColor('Yellow', Color(0xFFFDD835), digit: 4, exponent: 4),
  BandColor('Green', Color(0xFF43A047), digit: 5, exponent: 5, tolerance: 0.5),
  BandColor('Blue', Color(0xFF1E88E5), digit: 6, exponent: 6, tolerance: 0.25),
  BandColor('Violet', Color(0xFF8E24AA), digit: 7, exponent: 7, tolerance: 0.1),
  BandColor('Grey', Color(0xFF9E9E9E), digit: 8, exponent: 8, tolerance: 0.05),
  BandColor('White', Color(0xFFFFFFFF), digit: 9, exponent: 9),
  BandColor('Gold', Color(0xFFD4AF37), exponent: -1, tolerance: 5),
  BandColor('Silver', Color(0xFFC0C0C0), exponent: -2, tolerance: 10),
];

final _digitColors = bandColors.where((b) => b.digit != null).toList();
final _toleranceColors = bandColors.where((b) => b.tolerance != null).toList();

class ColorCodeScreen extends StatefulWidget {
  const ColorCodeScreen({super.key, required this.calc});

  final CalcDef calc;

  @override
  State<ColorCodeScreen> createState() => _ColorCodeScreenState();
}

class _ColorCodeScreenState extends State<ColorCodeScreen> {
  int _bands = 4;
  // Defaults: brown-black-red-gold = 1 kΩ ±5%
  final List<BandColor> _digits = [bandColors[1], bandColors[0], bandColors[0]];
  BandColor _multiplier = bandColors[2];
  BandColor _tolerance = bandColors[10];
  final _lookup = TextEditingController();
  String? _lookupNote;

  int get _digitCount => _bands == 4 ? 2 : 3;

  double get _value {
    var n = 0;
    for (final d in _digits.take(_digitCount)) {
      n = n * 10 + d.digit!;
    }
    return n * pow(10, _multiplier.exponent).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _lookup.addListener(_fromValue);
  }

  @override
  void dispose() {
    _lookup.dispose();
    super.dispose();
  }

  /// Sets the bands from a typed value, e.g. "4.7k".
  void _fromValue() {
    final v = parseSi(_lookup.text);
    if (v == null || v <= 0) {
      setState(() => _lookupNote = null);
      return;
    }
    final n = _digitCount;
    var e = (log(v) / ln10).floor() - (n - 1);
    var mantissa = (v / pow(10, e)).round();
    if (mantissa >= pow(10, n)) {
      mantissa ~/= 10;
      e++;
    }
    if (e < -2 || e > 9) {
      setState(() => _lookupNote = 'Out of range for color codes');
      return;
    }
    final s = mantissa.toString().padLeft(n, '0');
    setState(() {
      for (var i = 0; i < n; i++) {
        _digits[i] = _digitColors[int.parse(s[i])];
      }
      _multiplier = bandColors.firstWhere((b) => b.exponent == e);
      final exact = (_value - v).abs() / v < 1e-6;
      _lookupNote = exact
          ? null
          : 'Not exact with $n digits. Closest is ${formatSi(_value, 'Ω')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final tol = _tolerance.tolerance!;
    final allBands = [..._digits.take(_digitCount), _multiplier, _tolerance];
    final m = Mono.of(context);

    return CalcScaffold(
      calc: widget.calc,
      children: [
        FormulaCard(formulas: widget.calc.formulas, description: widget.calc.description),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 4, label: Text('4 bands')),
            ButtonSegment(value: 5, label: Text('5 bands')),
          ],
          selected: {_bands},
          onSelectionChanged: (s) {
            setState(() => _bands = s.first);
            if (_lookup.text.isNotEmpty) _fromValue();
          },
        ),
        const SizedBox(height: 20),
        _ResistorPicture(bands: allBands),
        const SizedBox(height: 12),
        const SizedBox(height: 8),
        Center(
          child: SelectableText(
            '${formatSi(value, 'Ω')}  ±${formatNumber(tol)}%',
            style: TextStyle(
              color: m.ink,
              fontSize: 30,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
              fontFeatures: tabular,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            '${formatSi(value * (1 - tol / 100), 'Ω')} – ${formatSi(value * (1 + tol / 100), 'Ω')}',
            style: TextStyle(color: m.gray, fontSize: 13, fontFeatures: tabular),
          ),
        ),
        const SectionLabel('Find colors for a value'),
        SiField(controller: _lookup, label: 'Resistor value', unit: 'Ω', hint: '4.7k'),
        if (_lookupNote != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(_lookupNote!, style: TextStyle(color: m.gray, fontSize: 12)),
          ),
        const SectionLabel('Or tap the colors'),
        for (var i = 0; i < _digitCount; i++)
          _BandPicker(
            title: '${['1st', '2nd', '3rd'][i]} digit',
            options: _digitColors,
            selected: _digits[i],
            onSelected: (b) => setState(() => _digits[i] = b),
            labelOf: (b) => '${b.digit}',
          ),
        _BandPicker(
          title: 'Multiplier',
          options: bandColors,
          selected: _multiplier,
          onSelected: (b) => setState(() => _multiplier = b),
          labelOf: (b) => '×${formatSi(pow(10, b.exponent).toDouble(), '')}',
        ),
        _BandPicker(
          title: 'Tolerance',
          options: _toleranceColors,
          selected: _tolerance,
          onSelected: (b) => setState(() => _tolerance = b),
          labelOf: (b) => '±${formatNumber(b.tolerance!)}%',
        ),
      ],
    );
  }
}

class _ResistorPicture extends StatelessWidget {
  const _ResistorPicture({required this.bands});

  final List<BandColor> bands;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(child: Container(height: 2, color: m.gray)),
          Container(
            width: 240,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF3A3A3A) : const Color(0xFFE6E6E6),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                for (var i = 0; i < bands.length; i++) ...[
                  // Tolerance band sits apart from the others.
                  if (i == bands.length - 1) const Spacer(),
                  Container(
                    width: 16,
                    color: bands[i].color,
                  ),
                  if (i < bands.length - 2) const SizedBox(width: 12),
                ],
              ],
            ),
          ),
          Expanded(child: Container(height: 2, color: m.gray)),
        ],
      ),
    );
  }
}

class _BandPicker extends StatelessWidget {
  const _BandPicker({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
  });

  final String title;
  final List<BandColor> options;
  final BandColor selected;
  final ValueChanged<BandColor> onSelected;
  final String Function(BandColor) labelOf;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(title, style: TextStyle(color: m.gray, fontSize: 13))),
              Text('${selected.name}  ${labelOf(selected)}',
                  style: TextStyle(
                      color: m.ink, fontSize: 13, fontFeatures: tabular)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final b in options)
                Tooltip(
                  message: '${b.name}  ${labelOf(b)}',
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onSelected(b),
                    // Selected swatch gets a black ring with a small gap.
                    child: Container(
                      width: 38,
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: b == selected ? m.ink : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: b.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: m.line),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
