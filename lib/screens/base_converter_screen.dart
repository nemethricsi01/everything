import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/calc.dart';
import '../core/store.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _F { hex, dec, bin, ascii }

const _labels = {
  _F.hex: 'Hex',
  _F.dec: 'Decimal',
  _F.bin: 'Binary',
  _F.ascii: 'ASCII text',
};

const _hints = {
  _F.hex: '48 69  or  0x4869',
  _F.dec: '18537  or  -1',
  _F.bin: '01001000 01101001',
  _F.ascii: 'Hi',
};

/// Parses [text] typed into field [f]. Returns the value or an error message.
(BigInt?, String?) _parse(_F f, String text) {
  switch (f) {
    case _F.hex:
      final s = text.toLowerCase().replaceAll('0x', '').replaceAll(RegExp(r'[\s_]'), '');
      if (!RegExp(r'^[0-9a-f]+$').hasMatch(s)) return (null, 'Only 0–9 and A–F');
      return (BigInt.parse(s, radix: 16), null);
    case _F.dec:
      final s = text.replaceAll(RegExp(r'[\s_]'), '');
      if (!RegExp(r'^-?\d+$').hasMatch(s)) return (null, 'Only digits (and a leading −)');
      var n = BigInt.parse(s);
      if (n.isNegative) {
        // Two's complement in the smallest common width that fits.
        var w = 8;
        while (n < -(BigInt.one << (w - 1))) {
          w *= 2;
        }
        n += BigInt.one << w;
      }
      return (n, null);
    case _F.bin:
      final s = text.toLowerCase().replaceAll('0b', '').replaceAll(RegExp(r'[\s_]'), '');
      if (!RegExp(r'^[01]+$').hasMatch(s)) return (null, 'Only 0 and 1');
      return (BigInt.parse(s, radix: 2), null);
    case _F.ascii:
      var v = BigInt.zero;
      for (final c in text.codeUnits) {
        if (c > 255) return (null, 'Only plain ASCII characters');
        v = (v << 8) | BigInt.from(c);
      }
      return (v, null);
  }
}

List<int> _bytes(BigInt v) {
  var h = v.toRadixString(16);
  if (h.length.isOdd) h = '0$h';
  return [
    for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16),
  ];
}

bool _printable(int b) => b >= 32 && b <= 126;

String _format(_F f, BigInt v) {
  switch (f) {
    case _F.hex:
      return _bytes(v)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
    case _F.dec:
      return v.toString();
    case _F.bin:
      return _bytes(v).map((b) => b.toRadixString(2).padLeft(8, '0')).join(' ');
    case _F.ascii:
      return String.fromCharCodes(
          _bytes(v).map((b) => _printable(b) ? b : 0xB7)); // ·
  }
}

class BaseConverterScreen extends StatefulWidget {
  const BaseConverterScreen({super.key, required this.calc});

  final CalcDef calc;

  @override
  State<BaseConverterScreen> createState() => _BaseConverterScreenState();
}

class _BaseConverterScreenState extends State<BaseConverterScreen> {
  final _c = {for (final f in _F.values) f: TextEditingController()};
  BigInt? _value;
  _F? _errorField;
  String? _error;
  bool _syncing = false;
  bool _showTable = false;

  @override
  void initState() {
    super.initState();
    final saved = Store.instance.inputs(widget.calc.id)['hex'] ?? '';
    if (saved.isNotEmpty) {
      _c[_F.hex]!.text = saved;
      _apply(_F.hex);
    }
    for (final f in _F.values) {
      _c[f]!.addListener(() {
        if (!_syncing) setState(() => _apply(f));
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

  /// Reads field [f] and rewrites the other fields from it.
  void _apply(_F f) {
    final text = _c[f]!.text;
    _error = null;
    _errorField = null;
    if (text.trim().isEmpty) {
      _value = null;
      _fillOthers(f);
    } else {
      final (v, err) = _parse(f, text);
      if (err != null) {
        // Keep the other fields as they were so nothing is lost.
        _error = err;
        _errorField = f;
        return;
      }
      _value = v;
      _fillOthers(f);
    }
    Store.instance.saveInputs(widget.calc.id,
        {'hex': _value == null ? '' : _format(_F.hex, _value!)});
  }

  void _fillOthers(_F source) {
    _syncing = true;
    for (final f in _F.values) {
      if (f != source) _c[f]!.text = _value == null ? '' : _format(f, _value!);
    }
    _syncing = false;
  }

  void _clear() {
    _syncing = true;
    for (final c in _c.values) {
      c.clear();
    }
    _syncing = false;
    setState(() {
      _value = null;
      _error = null;
      _errorField = null;
    });
    Store.instance.saveInputs(widget.calc.id, {'hex': ''});
  }

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    final v = _value;
    final mono = TextStyle(
      fontSize: 16,
      color: m.ink,
      fontFamily: monoFamily,
      fontFamilyFallback: monoFallback,
    );

    return CalcScaffold(
      calc: widget.calc,
      onClear: _clear,
      children: [
        FormulaCard(formulas: widget.calc.formulas, description: widget.calc.description),
        const SectionLabel('Type in any field'),
        for (final f in _F.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: _c[f],
              minLines: 1,
              maxLines: f == _F.bin ? 4 : 2,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization:
                  f == _F.hex ? TextCapitalization.characters : TextCapitalization.none,
              keyboardType: f == _F.dec
                  ? const TextInputType.numberWithOptions(signed: true)
                  : TextInputType.text,
              style: mono,
              decoration: InputDecoration(
                labelText: _labels[f],
                hintText: _hints[f],
                errorText: _errorField == f ? _error : null,
                suffixIcon: IconButton(
                  tooltip: 'Copy',
                  icon: Icon(Icons.copy, size: 16, color: m.gray),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _c[f]!.text));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('Copied ${_labels[f]}'),
                        duration: const Duration(seconds: 1),
                      ));
                  },
                ),
              ),
            ),
          ),
        const SectionLabel('Details'),
        ..._details(v),
        const Divider(),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: Icon(_showTable ? Icons.expand_less : Icons.expand_more),
            label: Text(_showTable ? 'Hide ASCII table' : 'Show ASCII table'),
            onPressed: () => setState(() => _showTable = !_showTable),
          ),
        ),
        if (_showTable) _AsciiTable(onTap: (code) {
          _c[_F.ascii]!.text += String.fromCharCode(code);
        }),
      ],
    );
  }

  List<Widget> _details(BigInt? v) {
    if (v == null) {
      return const [ResultTile(label: 'Octal', missing: 'Type a value above')];
    }
    final bytes = _bytes(v);
    final bits = v.bitLength;
    var w = 8;
    while (w < bits) {
      w *= 2;
    }
    final signed = bits == w ? v - (BigInt.one << w) : v;
    return [
      ResultTile(label: 'Octal', value: v.toRadixString(8)),
      ResultTile(
        label: 'Size',
        value: '$bits bits · ${bytes.length} byte${bytes.length == 1 ? '' : 's'}',
      ),
      ResultTile(
        label: 'As signed int$w',
        note: "two's complement",
        value: signed.toString(),
      ),
      if (bytes.length > 1)
        ResultTile(label: 'Bytes in decimal', value: bytes.join(' ')),
      if (bytes.any((b) => !_printable(b)))
        const ResultTile(
          label: 'ASCII',
          missing: 'Some bytes are not printable, shown as ·',
        ),
    ];
  }
}

/// Printable ASCII 32–126 as small cells: character over its hex code.
class _AsciiTable extends StatelessWidget {
  const _AsciiTable({required this.onTap});

  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var code = 32; code <= 126; code++)
            Tooltip(
              message: '${code == 32 ? 'Space' : String.fromCharCode(code)}  ·  '
                  'dec $code  ·  hex ${code.toRadixString(16).toUpperCase()}',
              child: InkWell(
                onTap: () => onTap(code),
                child: Container(
                  width: 44,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: m.line),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        code == 32 ? '␣' : String.fromCharCode(code),
                        style: TextStyle(
                          color: m.ink,
                          fontSize: 16,
                          fontFamily: monoFamily,
                          fontFamilyFallback: monoFallback,
                        ),
                      ),
                      Text(
                        code.toRadixString(16).toUpperCase(),
                        style: TextStyle(color: m.gray, fontSize: 11, fontFeatures: tabular),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
