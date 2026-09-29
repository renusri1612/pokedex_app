import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class FavoritesPreferences {
  Future<List<String>?> getStringList(String key);

  Future<void> setStringList(String key, List<String> value);
}

class SharedPreferencesFavoritesPreferences implements FavoritesPreferences {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<List<String>?> getStringList(String key) {
    return _preferences.getStringList(key);
  }

  @override
  Future<void> setStringList(String key, List<String> value) {
    return _preferences.setStringList(key, value);
  }
}

class FavoritesStore extends ChangeNotifier {
  static const String _storageKey = 'favorite_pokemon_ids';

  final FavoritesPreferences _preferences;
  final Set<int> _favoriteIds = <int>{};

  bool _isLoaded = false;
  bool _isDisposed = false;

  FavoritesStore({FavoritesPreferences? preferences})
    : _preferences = preferences ?? SharedPreferencesFavoritesPreferences();

  Set<int> get favoriteIds => Set<int>.unmodifiable(_favoriteIds);

  bool get isLoaded => _isLoaded;

  bool isFavorite(int pokemonId) {
    return _favoriteIds.contains(pokemonId);
  }

  Future<void> loadFavorites() async {
    final List<String>? savedIds = await _preferences.getStringList(
      _storageKey,
    );

    if (_isDisposed) return;

    _favoriteIds
      ..clear()
      ..addAll(
        (savedIds ?? <String>[])
            .map(int.tryParse)
            .whereType<int>()
            .where((id) => id > 0),
      );

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> toggleFavorite(int pokemonId) async {
    if (pokemonId <= 0) {
      throw ArgumentError.value(
        pokemonId,
        'pokemonId',
        'Pokemon ID must be positive.',
      );
    }

    if (!_isLoaded) {
      throw StateError('Load favorites before changing them.');
    }

    if (_favoriteIds.contains(pokemonId)) {
      _favoriteIds.remove(pokemonId);
    } else {
      _favoriteIds.add(pokemonId);
    }

    notifyListeners();

    await _preferences.setStringList(
      _storageKey,
      _favoriteIds.map((id) => id.toString()).toList(),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
