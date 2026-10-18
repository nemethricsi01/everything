import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/si.dart';
import '../widgets/common.dart';

/// Screen for any calculator defined as inputs → outputs in the registry.
class GenericCalcScreen extends StatefulWidget {
  const GenericCalcScreen({super.key, required this.calc});

  final CalcDef calc;

  @override
  State<GenericCalcScreen> createState() => _GenericCalcScreenState();
}

class _GenericCalcScreenState extends State<GenericCalcScreen> {
  late final PersistedControllers _c;

  @override
  void initState() {
    super.initState();
    _c = PersistedControllers(widget.calc.id,
        widget.calc.inputs.map((f) => f.key), () => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _labelFor(String key) =>
      widget.calc.inputs.firstWhere((f) => f.key == key).label;

  @override
  Widget build(BuildContext context) {
    final calc = widget.calc;
    final values = _c.values;
    return CalcScaffold(
      calc: calc,
      onClear: _c.clear,
      children: [
        FormulaCard(formulas: calc.formulas, description: calc.description),
        const SectionLabel('Inputs'),
        for (final f in calc.inputs)
          SiField(
            controller: _c[f.key],
            label: f.label,
            unit: f.unit,
            hint: f.hint,
            optional: f.optional,
            prefix: f.prefix,
          ),
        const PrefixTip(),
        const SectionLabel('Results'),
        for (final o in calc.outputs) _result(o, values),
      ],
    );
  }

  Widget _result(OutputField o, Map<String, double> values) {
    final missing = o.needs.where((k) => !values.containsKey(k)).toList();
    if (missing.isNotEmpty) {
      return ResultTile(
        label: o.label,
        missing: 'Needs ${missing.map(_labelFor).join(', ')}',
      );
    }
    final r = o.compute(values);
    if (r == null || !r.isFinite) {
      return ResultTile(label: o.label, missing: 'Not possible with these values');
    }
    return ResultTile(
      label: o.label,
      value: o.format != null
          ? o.format!(r, values)
          : formatSi(r, o.unit, prefix: o.prefix),
    );
  }
}
