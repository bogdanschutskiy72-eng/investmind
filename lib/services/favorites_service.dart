import 'package:flutter/foundation.dart';

class FavoritesService {
  FavoritesService._();

  static final FavoritesService instance = FavoritesService._();

  final ValueNotifier<Set<String>> favorites = ValueNotifier(<String>{});

  bool isFavorite(String company) {
    return favorites.value.contains(company);
  }

  void toggleFavorite(String company) {
    final updated = Set<String>.from(favorites.value);

    if (updated.contains(company)) {
      updated.remove(company);
    } else {
      updated.add(company);
    }

    favorites.value = updated;
  }

  void remove(String company) {
    final updated = Set<String>.from(favorites.value);
    updated.remove(company);
    favorites.value = updated;
  }
}