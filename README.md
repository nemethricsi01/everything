# Everything

All the electronics formulas I keep forgetting, in one app.
Every calculator shows its formulas on top, remembers what you typed,
and understands values like `4.7k`, `100n`, `2u2` or `4k7`.

**Calculators:** Ohm's law & power · series & parallel (R, C, L) · voltage divider ·
dB, dBu/dBV, dBm · resistor color code · LED resistor · missing parallel resistor ·
E6/E12/E24/E96 values · stored energy · RC low-pass / high-pass · RC filter design ·
RL filter · reactance · RLC impedance · LC resonance · op-amp gain · RC time constant ·
555 astable / one-shot · frequency & wavelength · RMS / peak / pp / average ·
linear regulator heat · battery life · hex / decimal / binary / ASCII.

## Run

```
flutter pub get
flutter run -d windows   # or android, web, ...
```

## Add a calculator

Most calculators are a single entry in `lib/calculators.dart`:
inputs, outputs with a compute function, and the formula text.
