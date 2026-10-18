import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/calc.dart';
import '../core/si.dart';
import '../core/store.dart';
import '../theme.dart';

/// App bar + centered, width-limited scrolling body shared by every
/// calculator screen.
class CalcScaffold extends StatelessWidget {
  const CalcScaffold({
    super.key,
    required this.calc,
    required this.children,
    this.onClear,
  });

  final CalcDef calc;
  final List<Widget> children;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(calc.title),
        actions: [
          if (onClear != null)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.backspace_outlined),
              onPressed: onClear,
            ),
          FavoriteButton(id: calc.id),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final fav = Store.instance.isFavorite(id);
        return IconButton(
          tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
          icon: Icon(fav ? Icons.star : Icons.star_border,
              color: fav ? m.ink : m.gray),
          onPressed: () => Store.instance.toggleFavorite(id),
        );
      },
    );
  }
}

class FormulaCard extends StatelessWidget {
  const FormulaCard({super.key, required this.formulas, this.description = ''});

  final List<String> formulas;
  final String description;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: m.faint,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Label('Formula'),
          const SizedBox(height: 10),
          for (final f in formulas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: SelectableText(
                f,
                style: TextStyle(
                  color: m.ink,
                  fontSize: 15,
                  height: 1.35,
                  fontFamily: monoFamily,
                  fontFamilyFallback: monoFallback,
                ),
              ),
            ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description,
                style: text.bodyMedium?.copyWith(color: m.gray, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// Small, spaced, uppercase gray caption.
class Label extends StatelessWidget {
  const Label(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Mono.of(context).gray,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 32, 0, 12),
      child: Row(
        children: [
          Expanded(child: Label(text)),
          ?trailing,
        ],
      ),
    );
  }
}

class PrefixTip extends StatelessWidget {
  const PrefixTip({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '4.7k · 100n · 2u2 · 4k7 · 10m = milli · 1M = mega',
        style: TextStyle(color: Mono.of(context).gray, fontSize: 12),
      ),
    );
  }
}

/// Text field that understands SI prefixes and shows what it understood.
class SiField extends StatelessWidget {
  const SiField({
    super.key,
    required this.controller,
    required this.label,
    required this.unit,
    this.hint,
    this.optional = false,
    this.prefix = true,
    this.showParsed = true,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final String? hint;
  final bool optional;
  final bool prefix;

  /// Show "= 4.7 kΩ" under the field so the user sees what was understood.
  final bool showParsed;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text.trim();
        final parsed = parseSi(text);
        String? helper;
        String? error;
        if (text.isNotEmpty) {
          if (parsed == null) {
            error = "Can't read that. Try 4.7k, 100n, 2u2";
          } else if (showParsed) {
            helper = '= ${formatSi(parsed, unit, prefix: prefix)}';
          }
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            style: TextStyle(fontSize: 16, color: m.ink, fontFeatures: tabular),
            decoration: InputDecoration(
              labelText: optional ? '$label · optional' : label,
              hintText: hint,
              suffixText: unit,
              helperText: helper,
              errorText: error,
              suffixIcon: text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(Icons.close, size: 16, color: m.gray),
                      onPressed: controller.clear,
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// One result row: label left, value right. Tap to copy the value.
class ResultTile extends StatelessWidget {
  const ResultTile({
    super.key,
    required this.label,
    this.value,
    this.missing,
    this.note,
    this.highlight = true,
  });

  final String label;

  /// Formatted result, or null if it can't be shown yet.
  final String? value;

  /// Shown instead of the value when it is null.
  final String? missing;

  /// Small text under the label.
  final String? note;

  /// False shows the value in gray, e.g. for values the user typed in.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    final hasValue = value != null;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: m.line))),
      child: InkWell(
        onTap: hasValue
            ? () {
                Clipboard.setData(ClipboardData(text: value!));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text('Copied  $value'),
                    duration: const Duration(seconds: 1),
                  ));
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: m.gray, fontSize: 14)),
                    if (note != null)
                      Text(note!,
                          style: TextStyle(color: m.gray, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 2,
                child: Text(
                  value ?? missing ?? '—',
                  textAlign: TextAlign.end,
                  style: hasValue
                      ? TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                          fontFeatures: tabular,
                          color: highlight ? m.ink : m.gray,
                        )
                      : TextStyle(
                          fontSize: 13,
                          color: m.gray.withValues(alpha: 0.7),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads saved text for [keys] into controllers and saves on every change.
class PersistedControllers {
  PersistedControllers(this.calcId, Iterable<String> keys, VoidCallback onChanged) {
    final saved = Store.instance.inputs(calcId);
    for (final k in keys) {
      final c = TextEditingController(text: saved[k] ?? '');
      c.addListener(() {
        save();
        onChanged();
      });
      map[k] = c;
    }
  }

  final String calcId;
  final Map<String, TextEditingController> map = {};
  Map<String, String> extra = {};

  TextEditingController operator [](String key) => map[key]!;

  Map<String, double> get values => {
        for (final e in map.entries)
          e.key: ?parseSi(e.value.text),
      };

  void save() => Store.instance.saveInputs(
      calcId, {...extra, for (final e in map.entries) e.key: e.value.text});

  void clear() {
    for (final c in map.values) {
      c.clear();
    }
  }

  void dispose() {
    for (final c in map.values) {
      c.dispose();
    }
  }
}
