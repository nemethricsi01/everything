import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/si.dart';
import '../core/store.dart';
import '../widgets/common.dart';

/// One field of a linked converter. Every field converts to and from a
/// shared base value; [mode] is the selected option (e.g. waveform).
class LinkedField {
  const LinkedField(
    this.key,
    this.label,
    this.unit, {
    required this.toBase,
    required this.fromBase,
    this.prefix = true,
    this.hint,
  });

  final String key;
  final String label;
  final String unit;
  final bool prefix;
  final String? hint;
  final double? Function(double v, String mode) toBase;
  final double? Function(double base, String mode) fromBase;
}

class LinkedConfig {
  const LinkedConfig({
    required this.fields,
    this.modes = const [],
    this.formulasFor,
    this.factsTitle = 'Good to know',
    this.facts,
  });

  final List<LinkedField> fields;
  final List<String> modes;
  final List<String> Function(String mode)? formulasFor;
  final String factsTitle;
  final List<(String, String)> Function(String mode)? facts;
}

/// "Type in any field, the others follow" converter.
class LinkedConverterScreen extends StatefulWidget {
  const LinkedConverterScreen({super.key, required this.calc, required this.config});

  final CalcDef calc;
  final LinkedConfig config;

  @override
  State<LinkedConverterScreen> createState() => _LinkedConverterScreenState();
}

class _LinkedConverterScreenState extends State<LinkedConverterScreen> {
  late String _mode;
  late final Map<String, TextEditingController> _c;
  String? _source;
  bool _syncing = false;

  LinkedConfig get _cfg => widget.config;

  @override
  void initState() {
    super.initState();
    final saved = Store.instance.inputs(widget.calc.id);
    _mode = _cfg.modes.contains(saved['mode'])
        ? saved['mode']!
        : (_cfg.modes.isEmpty ? '' : _cfg.modes.first);
    _c = {for (final f in _cfg.fields) f.key: TextEditingController()};

    final src = saved['source'];
    if (src != null && _c.containsKey(src)) {
      _c[src]!.text = saved['text'] ?? '';
      _source = src;
      _fill();
    }
    for (final f in _cfg.fields) {
      _c[f.key]!.addListener(() {
        if (_syncing) return;
        _source = f.key;
        _fill();
        _save();
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() => Store.instance.saveInputs(widget.calc.id, {
        'mode': _mode,
        'source': ?_source,
        if (_source != null) 'text': _c[_source]!.text,
      });

  /// Rewrites every field from the one the user last typed in.
  void _fill() {
    final src = _source;
    if (src == null) return;
    final text = _c[src]!.text;
    final v = parseSi(text);
    // Unreadable input: leave the other fields alone (the field shows why).
    if (v == null && text.trim().isNotEmpty) return;
    final field = _cfg.fields.firstWhere((f) => f.key == src);
    final base = v == null ? null : field.toBase(v, _mode);

    _syncing = true;
    for (final f in _cfg.fields) {
      if (f.key == src) continue;
      final out = base == null ? null : f.fromBase(base, _mode);
      _c[f.key]!.text = out == null || !out.isFinite
          ? ''
          : formatSi(out, '', prefix: f.prefix).replaceAll(' ', '');
    }
    _syncing = false;
  }

  void _clear() {
    _syncing = true;
    for (final c in _c.values) {
      c.clear();
    }
    _syncing = false;
    setState(() => _source = null);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final formulas = _cfg.formulasFor?.call(_mode) ?? widget.calc.formulas;
    final facts = _cfg.facts?.call(_mode) ?? const [];
    return CalcScaffold(
      calc: widget.calc,
      onClear: _clear,
      children: [
        if (_cfg.modes.isNotEmpty) ...[
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final m in _cfg.modes) ButtonSegment(value: m, label: Text(m)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() {
                _mode = s.first;
                _fill();
              });
              _save();
            },
          ),
          const SizedBox(height: 16),
        ],
        FormulaCard(formulas: formulas, description: widget.calc.description),
        const SectionLabel('Type in any field'),
        for (final f in _cfg.fields)
          SiField(
            controller: _c[f.key]!,
            label: f.label,
            unit: f.unit,
            hint: f.hint,
            prefix: f.prefix,
            showParsed: false,
          ),
        const PrefixTip(),
        if (facts.isNotEmpty) ...[
          SectionLabel(_cfg.factsTitle),
          for (final (label, value) in facts)
            ResultTile(label: label, value: value, highlight: false),
          const Divider(),
        ],
      ],
    );
  }
}
