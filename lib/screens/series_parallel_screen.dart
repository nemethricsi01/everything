import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/si.dart';
import '../core/store.dart';
import '../widgets/common.dart';

enum Part {
  r('R', 'Resistors', 'Ω'),
  c('C', 'Capacitors', 'F'),
  l('L', 'Inductors', 'H');

  const Part(this.symbol, this.label, this.unit);

  final String symbol;
  final String label;
  final String unit;
}

class SeriesParallelScreen extends StatefulWidget {
  const SeriesParallelScreen({super.key, required this.calc});

  final CalcDef calc;

  @override
  State<SeriesParallelScreen> createState() => _SeriesParallelScreenState();
}

class _SeriesParallelScreenState extends State<SeriesParallelScreen> {
  Part _part = Part.r;
  final List<TextEditingController> _fields = [];

  @override
  void initState() {
    super.initState();
    final saved = Store.instance.inputs(widget.calc.id);
    _part = Part.values.firstWhere((p) => p.name == saved['part'],
        orElse: () => Part.r);
    final count = int.tryParse(saved['count'] ?? '') ?? 2;
    for (var i = 0; i < count.clamp(2, 50); i++) {
      _add(saved['$i'] ?? '');
    }
  }

  void _add([String text = '']) {
    final c = TextEditingController(text: text)..addListener(_changed);
    _fields.add(c);
  }

  void _changed() {
    Store.instance.saveInputs(widget.calc.id, {
      'part': _part.name,
      'count': '${_fields.length}',
      for (var i = 0; i < _fields.length; i++) '$i': _fields[i].text,
    });
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _formulas {
    final s = _part.symbol;
    final sumSeries = '$s = $s' '1 + ${s}2 + …';
    final recip = '1/$s = 1/${s}1 + 1/${s}2 + …';
    final two = '$s = ${s}1·${s}2 / (${s}1 + ${s}2)';
    return switch (_part) {
      Part.r || Part.l => [
          'Series:   $sumSeries',
          'Parallel: $recip',
          'Two in parallel: $two',
        ],
      Part.c => [
          'Parallel: $sumSeries',
          'Series:   $recip',
          'Two in series: $two',
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final values = [for (final c in _fields) ?parseSi(c.text)]
        .where((v) => v > 0)
        .toList();
    final sum = values.fold<double>(0, (a, b) => a + b);
    final recip = 1 / values.fold<double>(0, (a, b) => a + 1 / b);
    final isCap = _part == Part.c;
    final series = isCap ? recip : sum;
    final parallel = isCap ? sum : recip;
    final ready = values.isNotEmpty;

    return CalcScaffold(
      calc: widget.calc,
      onClear: () {
        for (final c in _fields) {
          c.clear();
        }
      },
      children: [
        SegmentedButton<Part>(
          segments: [
            for (final p in Part.values)
              ButtonSegment(value: p, label: Text(p.label)),
          ],
          selected: {_part},
          onSelectionChanged: (s) {
            _part = s.first;
            _changed();
          },
        ),
        const SizedBox(height: 12),
        FormulaCard(
          formulas: _formulas,
          description: isCap
              ? 'Capacitors work the OPPOSITE way to resistors!'
              : 'Parallel total is always smaller than the smallest part.',
        ),
        SectionLabel('${_part.label} (${values.length} filled in)'),
        for (var i = 0; i < _fields.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SiField(
                  controller: _fields[i],
                  label: '${_part.symbol}${i + 1}',
                  unit: _part.unit,
                ),
              ),
              if (_fields.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      _fields.removeAt(i).dispose();
                      _changed();
                    },
                  ),
                ),
            ],
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Add ${_part.symbol}${_fields.length + 1}'),
            onPressed: () {
              _add();
              _changed();
            },
          ),
        ),
        const PrefixTip(),
        const SectionLabel('Results'),
        ResultTile(
          label: 'Series total',
          value: ready ? formatSi(series, _part.unit) : null,
          missing: 'Fill in at least one value',
        ),
        ResultTile(
          label: 'Parallel total',
          value: ready ? formatSi(parallel, _part.unit) : null,
          missing: 'Fill in at least one value',
        ),
      ],
    );
  }
}
