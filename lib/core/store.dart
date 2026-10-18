import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers favorites, recently used calculators and the last values typed
/// into each calculator, so nothing is lost when you leave a screen.
class Store extends ChangeNotifier {
  Store._();

  static final instance = Store._();

  late SharedPreferences _prefs;
  Set<String> _favorites = {};
  List<String> _recent = [];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _favorites = (_prefs.getStringList('favorites') ?? []).toSet();
    _recent = _prefs.getStringList('recent') ?? [];
  }

  Set<String> get favorites => _favorites;
  List<String> get recent => _recent;

  bool isFavorite(String id) => _favorites.contains(id);

  void toggleFavorite(String id) {
    if (!_favorites.remove(id)) _favorites.add(id);
    _prefs.setStringList('favorites', _favorites.toList());
    notifyListeners();
  }

  void markUsed(String id) {
    _recent
      ..remove(id)
      ..insert(0, id);
    if (_recent.length > 6) _recent = _recent.sublist(0, 6);
    _prefs.setStringList('recent', _recent);
    notifyListeners();
  }

  Map<String, String> inputs(String calcId) {
    final raw = _prefs.getString('inputs.$calcId');
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  void saveInputs(String calcId, Map<String, String> values) {
    _prefs.setString('inputs.$calcId', jsonEncode(values));
  }
}
