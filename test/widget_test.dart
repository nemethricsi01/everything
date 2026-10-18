import 'package:everything/calculators.dart';
import 'package:everything/core/eseries.dart';
import 'package:everything/core/si.dart';
import 'package:everything/core/store.dart';
import 'package:everything/main.dart';
import 'package:everything/screens/base_converter_screen.dart';
import 'package:everything/screens/ohm_screen.dart';
import 'package:everything/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('parseSi', () {
    test('plain and prefixed numbers', () {
      expect(parseSi('12'), 12);
      expect(parseSi('4.7k'), closeTo(4700, 1e-9));
      expect(parseSi('100n'), closeTo(100e-9, 1e-18));
      expect(parseSi('2.2uF'), closeTo(2.2e-6, 1e-15));
      expect(parseSi('10m'), closeTo(0.01, 1e-12));
      expect(parseSi('1M'), 1e6);
      expect(parseSi('1,5'), 1.5);
      expect(parseSi('1e3'), 1000);
      expect(parseSi('2000mAh'), closeTo(2, 1e-12));
      expect(parseSi('5.'), 5);
    });

    test('resistor notation', () {
      expect(parseSi('4k7'), closeTo(4700, 1e-9));
      expect(parseSi('4R7'), closeTo(4.7, 1e-12));
      expect(parseSi('2u2'), closeTo(2.2e-6, 1e-15));
    });

    test('garbage', () {
      expect(parseSi(''), isNull);
      expect(parseSi('abc'), isNull);
      expect(parseSi('1.2.3'), isNull);
    });
  });

  test('formatSi', () {
    expect(formatSi(4700, 'Ω'), '4.7 kΩ');
    expect(formatSi(1e-7, 'F'), '100 nF');
    expect(formatSi(999.99, 'Hz'), '1 kHz');
    expect(formatSi(0, 'V'), '0 V');
    expect(formatSi(-0.005, 'A'), '-5 mA');
    expect(formatSi(double.infinity, 'Ω'), '—');
  });

  test('E-series', () {
    expect(eNearest(5000, e12), closeTo(4700, 1e-6));
    expect(eNearest(9600, e12), closeTo(10000, 1e-6));
    expect(eNextUp(150, e12), closeTo(150, 1e-6));
    expect(eNextUp(151, e12), closeTo(180, 1e-6));
    expect(e96.length, 96);
    expect(e96[1], 1.02);
  });

  test("Ohm's law solver", () {
    final r = solveOhm({'v': 12, 'i': 0.02});
    expect(r['r'], closeTo(600, 1e-9));
    expect(r['p'], closeTo(0.24, 1e-12));
    final r2 = solveOhm({'r': 100, 'p': 1});
    expect(r2['v'], closeTo(10, 1e-9));
    expect(r2['i'], closeTo(0.1, 1e-12));
  });

  testWidgets('hex / decimal / binary / ASCII stay in sync', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.load();
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: BaseConverterScreen(calc: calcById('base_convert')),
    ));
    final fields = find.byType(TextField);
    String text(int i) => tester.widget<TextField>(fields.at(i)).controller!.text;

    await tester.enterText(fields.at(3), 'Hi');
    await tester.pump();
    expect(text(0), '48 69');
    expect(text(1), '18537');
    expect(text(2), '01001000 01101001');

    await tester.enterText(fields.at(1), '-1');
    await tester.pump();
    expect(text(0), 'FF');
    expect(text(2), '11111111');

    await tester.enterText(fields.at(0), '0x41');
    await tester.pump();
    expect(text(1), '65');
    expect(text(3), 'A');

    await tester.enterText(fields.at(2), '12');
    await tester.pump();
    expect(find.text('Only 0 and 1'), findsOneWidget);
    expect(text(3), 'A'); // others untouched on bad input
  });

  testWidgets('dBu and RMS converters', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.load();
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fields = find.byType(TextField);
    String text(int i) => tester.widget<TextField>(fields.at(i)).controller!.text;

    final dbu = calcById('dbu');
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: dbu.screen!(dbu)));
    await tester.enterText(fields.at(0), '+4');
    await tester.pump();
    expect(text(1), '1.782'); // dBV
    expect(text(2), '1.228'); // Vrms
    expect(text(4), '3.472'); // Vpp

    final rms = calcById('rms');
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: rms.screen!(rms)));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(0), '1');
    await tester.pump();
    expect(text(1), '2');
    expect(text(2), '707.1m');
    expect(text(3), '636.6m');
    await tester.tap(find.text('Square'));
    await tester.pump();
    expect(text(2), '1');
    await tester.tap(find.text('Triangle'));
    await tester.pump();
    expect(text(2), '577.4m');
    expect(text(3), '500m');
  });

  testWidgets('every calculator opens without errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Store.instance.load();
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const EverythingApp());
    for (final calc in calculators) {
      await tester.scrollUntilVisible(find.text(calc.title).last, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(calc.title).last);
      await tester.pumpAndSettle();
      expect(find.text('FORMULA'), findsOneWidget, reason: calc.id);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
