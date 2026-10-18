import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/calc.dart';
import '../core/si.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// One option of a DRV8234 2-bit scale field.
class _Scale {
  const _Scale(this.code, this.value, {this.label, this.maxRadS});

  final int code;
  final int value;
  final String? label;
  final int? maxRadS;

  String get bits => '${code.toRadixString(2).padLeft(2, '0')}b';
  String get name => label ?? '$value';
}

// Datasheet Table 7-11
const _invRScales = [_Scale(0, 2), _Scale(1, 64), _Scale(2, 1024), _Scale(3, 8192)];
// Datasheet Table 7-12: 24×2^8, 24×2^9, 24×2^12, 24×2^13
const _kmcScales = [
  _Scale(0, 24 * 256, label: '24×2⁸'),
  _Scale(1, 24 * 512, label: '24×2⁹'),
  _Scale(2, 24 * 4096, label: '24×2¹²'),
  _Scale(3, 24 * 8192, label: '24×2¹³'),
];
// Datasheet Table 7-21
const _wScales = [
  _Scale(0, 16, maxRadS: 4080),
  _Scale(1, 32, maxRadS: 8160),
  _Scale(2, 64, maxRadS: 16320),
  _Scale(3, 128, maxRadS: 32640),
];

typedef _Pick = ({_Scale scale, int reg, bool overflow});

bool _fits(int v) => v >= 1 && v <= 255;

/// Largest scale whose rounded register value still fits in 1–255,
/// else the smallest scale flagged as overflowing.
_Pick _pickLargest(List<_Scale> scales, int Function(_Scale) regFor) {
  _Pick? best;
  for (final s in scales) {
    final r = regFor(s);
    if (_fits(r)) best = (scale: s, reg: r, overflow: false);
  }
  if (best != null) return best;
  final r = regFor(scales.first);
  return (scale: scales.first, reg: r, overflow: true);
}

/// Smallest W_SCALE that can represent the target (best resolution).
_Pick _pickWScale(double rippleRadS) {
  for (final s in _wScales) {
    final r = (rippleRadS / s.value).round();
    if (_fits(r) && rippleRadS <= s.maxRadS!) {
      return (scale: s, reg: r, overflow: false);
    }
  }
  final s = _wScales.last;
  final r = (rippleRadS / s.value).round();
  return (scale: s, reg: r, overflow: !_fits(r));
}

int _clamp8(int v) => v.clamp(0, 255);

String _fixed(double v, int digits) => v.isFinite ? v.toStringAsFixed(digits) : '—';

String _hex(int v) => '0x${v.toRadixString(16).toUpperCase().padLeft(2, '0')}';

class MotorScreen extends StatefulWidget {
  const MotorScreen({super.key, required this.calc});

  final CalcDef calc;

  @override
  State<MotorScreen> createState() => _MotorScreenState();
}

class _MotorScreenState extends State<MotorScreen> {
  late final PersistedControllers _c;

  @override
  void initState() {
    super.initState();
    _c = PersistedControllers(
        widget.calc.id, const ['r', 'v', 'i', 'hz', 'nr', 'target'], () => setState(() {}));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Fills inputs from a spreadsheet row: R, L, V, mA, Hz (L is ignored).
  Future<void> _pasteRow() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final line = (data?.text ?? '').trim().split(RegExp(r'\r?\n')).first.trim();
    final parts = line.split(RegExp(r'\s+'));
    final nums = parts.map((p) => double.tryParse(p.replaceAll(',', '.'))).toList();
    if (!mounted) return;
    if (parts.length != 5 || nums.any((n) => n == null)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Clipboard needs one row of 5 numbers: R  L  V  mA  Hz')));
      return;
    }
    _c['r'].text = parts[0];
    _c['v'].text = parts[2];
    _c['i'].text = '${parts[3]}m';
    _c['hz'].text = parts[4];
  }

  @override
  Widget build(BuildContext context) {
    final v = _c.values;
    final r = v['r'], volts = v['v'], inl = v['i'], hz = v['hz'];
    final nr = (v['nr'] ?? 6).round();
    final targetRpm = v['target'] ?? 2400;

    // Speed constants
    final speedOk = volts != null && volts > 0 && hz != null && hz >= 0;
    final rpm = speedOk ? hz * 60 : null;
    final omega = speedOk ? hz * 2 * pi : null;
    final ke = speedOk ? volts / omega! : null;
    double? eb;
    double? keIr;
    if (speedOk && r != null && r > 0 && inl != null && inl >= 0 && omega! > 0) {
      eb = volts - inl * r;
      if (eb > 0) keIr = eb / omega;
    }

    // DRV8234 registers
    final invR = r != null && r > 0
        ? _pickLargest(_invRScales, (s) => (s.value / r).round())
        : null;
    _Pick? kmcFor(double? k) => k != null && k > 0 && k.isFinite && nr > 0
        ? _pickLargest(_kmcScales, (s) => (k / nr * s.value).round())
        : null;
    final kmc = kmcFor(ke);
    final kmcIr = kmcFor(keIr);
    final ripple = targetRpm * nr * 2 * pi / 60;
    final w = ripple > 0 ? _pickWScale(ripple) : null;

    String reg(_Pick? p) => p == null
        ? '—'
        : '${_clamp8(p.reg)}${p.overflow ? '  (clamped)' : ''}';

    return CalcScaffold(
      calc: widget.calc,
      onClear: _c.clear,
      children: [
        FormulaCard(formulas: widget.calc.formulas, description: widget.calc.description),
        SectionLabel(
          'Measured at no load',
          trailing: TextButton.icon(
            icon: const Icon(Icons.content_paste, size: 16),
            label: const Text('Paste row'),
            onPressed: _pasteRow,
          ),
        ),
        SiField(controller: _c['r'], label: 'Motor resistance', unit: 'Ω', hint: '11.5'),
        SiField(controller: _c['v'], label: 'Voltage', unit: 'V', hint: '5.15'),
        SiField(controller: _c['i'], label: 'No-load current', unit: 'A', hint: '18m'),
        SiField(controller: _c['hz'], label: 'Shaft speed', unit: 'Hz', hint: '57'),
        SiField(
            controller: _c['nr'],
            label: 'Ripples per revolution NR',
            unit: '',
            hint: '6',
            optional: true,
            prefix: false),
        SiField(
            controller: _c['target'],
            label: 'Target speed',
            unit: 'RPM',
            hint: '2400',
            optional: true,
            prefix: false),
        Text(
          'Paste row reads a spreadsheet row: R  L  V  mA  Hz (L is ignored).',
          style: TextStyle(color: Mono.of(context).gray, fontSize: 12),
        ),

        const SectionLabel('Speed constants'),
        _row('RPM', 'Hz × 60', rpm == null ? null : '${_fixed(rpm, 2)} rpm'),
        _row('Kv  velocity constant', 'RPM / V',
            rpm == null ? null : '${_fixed(rpm / volts!, 3)} rpm/V'),
        _row('ω  angular velocity', 'Hz × 2π',
            omega == null ? null : '${_fixed(omega, 3)} rad/s'),
        _row(
            'Ke  back-EMF constant',
            'V / ω. The DRV8234 datasheet calls this Kv: use it where the datasheet says Kv.',
            ke == null ? null : '${_fixed(ke, 6)} V·s/rad'),
        _row(
            'Ke  IR-compensated',
            'Eb = V − I·R, then Ke = Eb / ω',
            keIr != null
                ? '${_fixed(keIr, 6)} V·s/rad'
                : eb != null
                    ? 'Eb = ${_fixed(eb, 3)} V  (≤ 0)'
                    : null,
            missing: 'Needs resistance and current'),
        const Divider(),

        const SectionLabel('DRV8234 · resistance'),
        _row('INV_R_SCALE', 'Largest of 2, 64, 1024, 8192 that keeps INV_R in 1–255',
            invR?.scale.name),
        _row('INV_R', 'round(INV_R_SCALE / R)', invR == null ? null : reg(invR)),
        const Divider(),

        SectionLabel('DRV8234 · motor constant  (NR = $nr)'),
        _row('KMC_SCALE', 'From Ke', kmc == null ? null : '${kmc.scale.name}  (${kmc.scale.value})'),
        _row('KMC', 'round(Ke / NR × KMC_SCALE)', kmc == null ? null : reg(kmc)),
        _row('KMC_SCALE  IR-compensated', 'From Ke (IR)',
            kmcIr == null ? null : '${kmcIr.scale.name}  (${kmcIr.scale.value})'),
        _row('KMC  IR-compensated', 'round(Ke(IR) / NR × KMC_SCALE)',
            kmcIr == null ? null : reg(kmcIr)),
        const Divider(),

        SectionLabel('DRV8234 · target speed  (${formatNumber(targetRpm)} RPM)'),
        _row('Target ripple speed', 'RPM × NR × 2π / 60', '${_fixed(ripple, 2)} rad/s'),
        _row('W_SCALE', 'Smallest of 16, 32, 64, 128 that covers the target',
            w == null ? null : '${w.scale.value}  (max ${w.scale.maxRadS} rad/s)'),
        _row('WSET_VSET', 'round(ripple speed / W_SCALE)', w == null ? null : reg(w)),
        const Divider(),

        const SectionLabel('Register bits'),
        Text('MSB (bit 7) on the left. Filled = 1.',
            style: TextStyle(color: Mono.of(context).gray, fontSize: 12)),
        const SizedBox(height: 12),
        _scaleBits('RC_CTRL2 (0x13) — INV_R_SCALE', invR),
        _byteBits('RC_CTRL3 (0x14) — INV_R', invR),
        _scaleBits('RC_CTRL2 (0x13) — KMC_SCALE', kmc),
        _byteBits('RC_CTRL4 (0x15) — KMC', kmc),
        _scaleBits('RC_CTRL2 (0x13) — KMC_SCALE  IR-compensated', kmcIr),
        _byteBits('RC_CTRL4 (0x15) — KMC  IR-compensated', kmcIr),
        _scaleBits('REG_CTRL0 (0x0E) — W_SCALE', w),
        _byteBits('REG_CTRL1 (0x0F) — WSET_VSET', w),

        const SectionLabel('Register reference'),
        Text('Ripple counting / RC_OUT bits. Filled = the bit for the enabled state.',
            style: TextStyle(color: Mono.of(context).gray, fontSize: 12)),
        const SizedBox(height: 12),
        const _BitRegister(
          title: 'RC_CTRL0 (0x11) bit 7 — EN_RC',
          note: 'Enable ripple counting. Must be 1 for the ripple-count algorithm / RC_OUT.',
          label: 'RC enabled: EN_RC = 1',
          value: 0x80,
          width: 8,
          highlight: {7},
        ),
        const _BitRegister(
          title: 'RC_CTRL0 (0x11) bit 6 — DIS_EC',
          note: 'Disable error correction. 0 = EC enabled (RC_OUT can pulse). '
              '1 = EC disabled (no RC_OUT pulses).',
          label: 'EC enabled: DIS_EC = 0',
          value: 0x80,
          width: 8,
          highlight: {6},
        ),
        const _BitRegister(
          title: 'RC_CTRL6 (0x17) bit 7 — EC_PULSE_DIS',
          note: 'Only when DIS_EC = 0. 0 = normal RC_OUT pulse train. 1 = stop pulses if EC '
              'inserts 12 pulses in a row with no bandpass activity.',
          label: 'Pulses enabled: EC_PULSE_DIS = 0',
          value: 0x00,
          width: 8,
          highlight: {7},
        ),
      ],
    );
  }

  Widget _row(String label, String note, String? value, {String? missing}) => ResultTile(
        label: label,
        note: note,
        value: value,
        missing: missing ?? 'Fill in the measurements',
      );

  Widget _scaleBits(String title, _Pick? p) => _BitRegister(
        title: title,
        label: p == null ? null : 'code ${p.scale.code} (${p.scale.bits}) · scale ${p.scale.name}',
        value: p?.scale.code,
        width: 2,
      );

  Widget _byteBits(String title, _Pick? p) {
    final v = p == null ? null : _clamp8(p.reg);
    return _BitRegister(
      title: title,
      label: v == null ? null : 'value $v (${_hex(v)})',
      value: v,
      width: 8,
    );
  }
}

/// A register field drawn as a row of bit cells, MSB first.
class _BitRegister extends StatelessWidget {
  const _BitRegister({
    required this.title,
    required this.label,
    required this.value,
    required this.width,
    this.note,
    this.highlight,
  });

  final String title;
  final String? note;
  final String? label;
  final int? value;
  final int width;

  /// Bits to fill. Defaults to the bits that are 1.
  final Set<int>? highlight;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    final v = value;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: m.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: m.ink,
                  fontSize: 13,
                  fontFamily: monoFamily,
                  fontFamilyFallback: monoFallback)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!, style: TextStyle(color: m.gray, fontSize: 11, height: 1.35)),
          ],
          const SizedBox(height: 8),
          if (v == null)
            Text('—', style: TextStyle(color: m.gray))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = width - 1; i >= 0; i--) _cell(m, i, (v >> i) & 1),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(label ?? '',
                      style: TextStyle(color: m.gray, fontSize: 12, fontFeatures: tabular)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(Mono m, int index, int bit) {
    final on = highlight?.contains(index) ?? bit == 1;
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Column(
        children: [
          Text('$index', style: TextStyle(color: m.gray, fontSize: 9, fontFeatures: tabular)),
          const SizedBox(height: 2),
          Container(
            width: 24,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? m.ink : null,
              border: Border.all(color: on ? m.ink : m.line),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              '$bit',
              style: TextStyle(
                color: on ? m.bg : m.ink,
                fontSize: 13,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                fontFamily: monoFamily,
                fontFamilyFallback: monoFallback,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
