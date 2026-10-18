import 'package:flutter/material.dart';

/// The whole palette: ink, gray, hairline, a faint fill and the background.
class Mono extends ThemeExtension<Mono> {
  const Mono({
    required this.ink,
    required this.gray,
    required this.line,
    required this.faint,
    required this.bg,
  });

  final Color ink;
  final Color gray;
  final Color line;
  final Color faint;
  final Color bg;

  static const light = Mono(
    ink: Color(0xFF111111),
    gray: Color(0xFF767676),
    line: Color(0xFFE3E3E3),
    faint: Color(0xFFF5F5F5),
    bg: Color(0xFFFFFFFF),
  );

  static const dark = Mono(
    ink: Color(0xFFF0F0F0),
    gray: Color(0xFF9A9A9A),
    line: Color(0xFF2C2C2C),
    faint: Color(0xFF1A1A1A),
    bg: Color(0xFF0F0F0F),
  );

  static Mono of(BuildContext context) => Theme.of(context).extension<Mono>()!;

  @override
  Mono copyWith({Color? ink, Color? gray, Color? line, Color? faint, Color? bg}) =>
      Mono(
        ink: ink ?? this.ink,
        gray: gray ?? this.gray,
        line: line ?? this.line,
        faint: faint ?? this.faint,
        bg: bg ?? this.bg,
      );

  @override
  Mono lerp(Mono? other, double t) {
    if (other == null) return this;
    return Mono(
      ink: Color.lerp(ink, other.ink, t)!,
      gray: Color.lerp(gray, other.gray, t)!,
      line: Color.lerp(line, other.line, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      bg: Color.lerp(bg, other.bg, t)!,
    );
  }
}

const monoFamily = 'monospace';
const monoFallback = ['Consolas', 'Menlo', 'Roboto Mono'];
const tabular = [FontFeature.tabularFigures()];

const _radius = BorderRadius.all(Radius.circular(2));

ThemeData buildTheme(Brightness brightness) {
  final m = brightness == Brightness.light ? Mono.light : Mono.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: m.ink,
    onPrimary: m.bg,
    primaryContainer: m.faint,
    onPrimaryContainer: m.ink,
    secondary: m.ink,
    onSecondary: m.bg,
    secondaryContainer: m.faint,
    onSecondaryContainer: m.ink,
    error: m.ink,
    onError: m.bg,
    surface: m.bg,
    onSurface: m.ink,
    onSurfaceVariant: m.gray,
    surfaceContainerLowest: m.bg,
    surfaceContainerLow: m.bg,
    surfaceContainer: m.faint,
    surfaceContainerHigh: m.faint,
    surfaceContainerHighest: m.faint,
    outline: m.gray,
    outlineVariant: m.line,
    surfaceTint: Colors.transparent,
    inverseSurface: m.ink,
    onInverseSurface: m.bg,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: _radius,
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: m.bg,
    extensions: [m],
    splashFactory: InkRipple.splashFactory,
    splashColor: m.ink.withValues(alpha: 0.05),
    highlightColor: m.ink.withValues(alpha: 0.04),
    hoverColor: m.ink.withValues(alpha: 0.03),
    appBarTheme: AppBarTheme(
      backgroundColor: m.bg,
      foregroundColor: m.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: m.line)),
      titleTextStyle: TextStyle(
          color: m.ink, fontSize: 17, fontWeight: FontWeight.w500),
    ),
    iconTheme: IconThemeData(color: m.ink, size: 20),
    dividerTheme: DividerThemeData(color: m.line, thickness: 1, space: 1),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: m.ink,
      selectionColor: m.ink.withValues(alpha: 0.15),
      selectionHandleColor: m.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border(m.line),
      enabledBorder: border(m.line),
      focusedBorder: border(m.ink, 1.5),
      errorBorder: border(m.ink),
      focusedErrorBorder: border(m.ink, 1.5),
      labelStyle: TextStyle(color: m.gray),
      floatingLabelStyle: TextStyle(color: m.ink),
      hintStyle: TextStyle(color: m.gray.withValues(alpha: 0.6)),
      helperStyle: TextStyle(color: m.gray, fontFeatures: tabular),
      errorStyle: TextStyle(color: m.ink),
      suffixStyle: TextStyle(color: m.gray),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: _radius)),
        side: WidgetStatePropertyAll(BorderSide(color: m.ink)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? m.ink : m.bg),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? m.bg : m.ink),
        iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? m.bg : m.ink),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: m.ink,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: m.ink, borderRadius: _radius),
      textStyle: TextStyle(color: m.bg, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: m.ink,
      contentTextStyle: TextStyle(color: m.bg),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: _radius),
      elevation: 0,
    ),
  );
}
