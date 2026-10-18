import 'package:flutter/material.dart';

class InputField {
  const InputField(
    this.key,
    this.label,
    this.unit, {
    this.hint,
    this.optional = false,
    this.prefix = true,
  });

  final String key;
  final String label;
  final String unit;
  final String? hint;
  final bool optional;

  /// Whether to show the value with SI prefixes (k, m, µ…).
  final bool prefix;
}

class OutputField {
  const OutputField(
    this.label,
    this.unit, {
    required this.needs,
    required this.compute,
    this.prefix = true,
    this.format,
  });

  final String label;
  final String unit;

  /// Input keys that must be filled in before this result is shown.
  final List<String> needs;

  /// Returns null when the inputs don't make sense (e.g. negative resistor).
  final double? Function(Map<String, double> v) compute;
  final bool prefix;

  /// Custom formatting of the result, if the default isn't good enough.
  final String Function(double result, Map<String, double> v)? format;
}

class CalcDef {
  const CalcDef({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.formulas,
    this.description = '',
    this.inputs = const [],
    this.outputs = const [],
    this.tags = const [],
    this.screen,
  });

  final String id;
  final String title;
  final String category;
  final IconData icon;
  final List<String> formulas;
  final String description;
  final List<InputField> inputs;
  final List<OutputField> outputs;
  final List<String> tags;

  /// Custom screen for calculators that don't fit the inputs → outputs shape.
  final Widget Function(CalcDef calc)? screen;

  bool matches(String query) {
    final haystack = [title, category, description, ...tags, ...formulas]
        .join(' ')
        .toLowerCase();
    return query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .every(haystack.contains);
  }
}
