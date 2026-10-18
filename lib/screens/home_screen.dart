import 'package:flutter/material.dart';

import '../calculators.dart';
import '../core/calc.dart';
import '../core/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'generic_calc_screen.dart';

void openCalc(BuildContext context, CalcDef calc) {
  Store.instance.markUsed(calc.id);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => calc.screen?.call(calc) ?? GenericCalcScreen(calc: calc),
  ));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListenableBuilder(
              listenable: Store.instance,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                children: [
                  Text(
                    'Everything',
                    style: TextStyle(
                      color: m.ink,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${calculators.length} calculators',
                      style: TextStyle(color: m.gray, fontSize: 13)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _search,
                    onChanged: (q) => setState(() => _query = q.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search — filter, 555, led, power',
                      prefixIcon: Icon(Icons.search, color: m.gray, size: 18),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: Icon(Icons.close, size: 16, color: m.gray),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                  ...(_query.isEmpty ? _overview(context) : _searchResults(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _searchResults(BuildContext context) {
    final found = calculators.where((c) => c.matches(_query)).toList();
    if (found.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text('Nothing found.',
              style: TextStyle(color: Mono.of(context).gray)),
        ),
      ];
    }
    return [
      const SectionLabel('Results'),
      ..._rows(found),
    ];
  }

  List<Widget> _overview(BuildContext context) {
    final m = Mono.of(context);
    final store = Store.instance;
    final favorites = calculators.where((c) => store.isFavorite(c.id)).toList();
    final recent = [
      for (final id in store.recent) ...calculators.where((c) => c.id == id),
    ];
    return [
      if (recent.isNotEmpty) ...[
        const SectionLabel('Recent'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final c in recent) _Pill(calc: c)],
        ),
      ],
      const SectionLabel('Favorites'),
      if (favorites.isEmpty)
        Text('Tap ☆ on any calculator to keep it here.',
            style: TextStyle(color: m.gray, fontSize: 14))
      else
        ..._rows(favorites),
      for (final cat in Cat.all) ...[
        SectionLabel(cat),
        ..._rows(calculators.where((c) => c.category == cat)),
      ],
    ];
  }

  List<Widget> _rows(Iterable<CalcDef> calcs) => [
        for (final c in calcs) _CalcRow(calc: c),
        const Divider(),
      ];
}

class _Pill extends StatelessWidget {
  const _Pill({required this.calc});

  final CalcDef calc;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(2),
      onTap: () => openCalc(context, calc),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: m.line),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(calc.title, style: TextStyle(color: m.ink, fontSize: 13)),
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  const _CalcRow({required this.calc});

  final CalcDef calc;

  @override
  Widget build(BuildContext context) {
    final m = Mono.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: m.line))),
      child: InkWell(
        onTap: () => openCalc(context, calc),
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(calc.title,
                        style: TextStyle(
                            color: m.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    // The main formula right in the list, to glance it up.
                    Text(
                      calc.formulas.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: m.gray,
                        fontSize: 13,
                        fontFamily: monoFamily,
                        fontFamilyFallback: monoFallback,
                      ),
                    ),
                  ],
                ),
              ),
              FavoriteButton(id: calc.id),
            ],
          ),
        ),
      ),
    );
  }
}
