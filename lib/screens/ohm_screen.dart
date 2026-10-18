import 'dart:math';

import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/si.dart';
import '../widgets/common.dart';

const _fields = [
  ('v', 'Voltage', 'V', '12'),
  ('i', 'Current', 'A', '20m'),
  ('r', 'Resistance', 'Ω', '600'),
  ('p', 'Power', 'W', ''),
];

/// Solves V, I, R, P from any two of them.
Map<String, double> solveOhm(Map<String, double> k) {
  double? v = k['v'], i = k['i'], r = k['r'], p = k['p'];
  if (v != null && i != null) {
    r = v / i;
    p = v * i;
  } else if (v != null && r != null) {
    i = v / r;
    p = v * v / r;
  } else if (v != null && p != null) {
    i = p / v;
    r = v * v / p;
  } else if (i != null && r != null) {
    v = i * r;
    p = i * i * r;
  } else if (i != null && p != null) {
    v = p / i;
    r = p / (i * i);
  } else if (r != null && p != null) {
    v = sqrt(p * r);
    i = sqrt(p / r);
  }
  return {
    'v': ?v,
    'i': ?i,
    'r': ?r,
    'p': ?p,
  };
}

class OhmScreen extends StatefulWidget {
  const OhmScreen({super.key, required this.calc});

  final CalcDef calc;

  @override
  State<OhmScreen> createState() => _OhmScreenState();
}

class _OhmScreenState extends State<OhmScreen> {
  late final PersistedControllers _c;

  @override
  void initState() {
    super.initState();
    _c = PersistedControllers(
        widget.calc.id, _fields.map((f) => f.$1), () => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final known = _c.values;
    String? message;
    Map<String, double> result = {};
    if (known.length < 2) {
      message = 'Fill in any two values (${2 - known.length} more to go).';
    } else if (known.length > 2) {
      message = 'You filled in ${known.length} values. Clear one so only two are left.';
    } else {
      result = solveOhm(known);
    }

    return CalcScaffold(
      calc: widget.calc,
      onClear: _c.clear,
      children: [
        FormulaCard(
            formulas: widget.calc.formulas,
            description: widget.calc.description),
        const SectionLabel('Inputs: any two'),
        for (final (key, label, unit, hint) in _fields)
          SiField(
            controller: _c[key],
            label: label,
            unit: unit,
            hint: hint.isEmpty ? null : hint,
          ),
        const PrefixTip(),
        SectionLabel('Results'),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(message),
          ),
        for (final (key, label, unit, _) in _fields)
          ResultTile(
            label: label,
            note: known.containsKey(key) ? 'you entered this' : null,
            highlight: !known.containsKey(key),
            value: result.containsKey(key) ? formatSi(result[key]!, unit) : null,
          ),
      ],
    );
  }
}
