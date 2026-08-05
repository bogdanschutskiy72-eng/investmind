import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  FavoritesService._();

  static final FavoritesService instance = FavoritesService._();

  static const String _storageKey = 'favorite_companies';

  final ValueNotifier<Set<String>> favorites =
      ValueNotifier<Set<String>>(<String>{});

  late SharedPreferences _preferences;

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();

    final savedCompanies =
        _preferences.getStringList(_storageKey) ?? <String>[];

    favorites.value = savedCompanies.toSet();
  }

  bool isFavorite(String company) {
    return favorites.value.contains(company);
  }

  Future<void> toggleFavorite(String company) async {
    final updated = Set<String>.from(favorites.value);

    if (updated.contains(company)) {
      updated.remove(company);
    } else {
      updated.add(company);
    }

    favorites.value = updated;

    await _save(updated);
  }

  Future<void> remove(String company) async {
    final updated = Set<String>.from(favorites.value)
      ..remove(company);

    favorites.value = updated;

    await _save(updated);
  }

  Future<void> _save(Set<String> companies) async {
    final sortedCompanies = companies.toList()..sort();

    await _preferences.setStringList(
      _storageKey,
      sortedCompanies,
    );
  }
}