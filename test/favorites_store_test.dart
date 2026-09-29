
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/state/favorites_store.dart';

class FakePreferences implements FavoritesPreferences {
  final Map<String, List<String>> _data = {};

  @override
  Future<List<String>?> getStringList(String key) async {
    return _data[key]?.toList();
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _data[key] = value.toList();
  }
}

void main() {
  group('FavoritesStore', () {
    late FakePreferences preferences;
    late FavoritesStore store;

    setUp(() async {
      preferences = FakePreferences();
      store = FavoritesStore(preferences: preferences);
      await store.loadFavorites();
    });

    tearDown(() {
      store.dispose();
    });

    test('loads saved favorite IDs', () async {
      final savedPreferences = FakePreferences();

      await savedPreferences.setStringList(
        'favorite_pokemon_ids',
        ['1', '25'],
      );

      final savedStore = FavoritesStore(preferences: savedPreferences);
      await savedStore.loadFavorites();

      expect(savedStore.isFavorite(1), isTrue);
      expect(savedStore.isFavorite(25), isTrue);
      expect(savedStore.isFavorite(4), isFalse);

      savedStore.dispose();
    });

    test('adding a favorite updates and persists it', () async {
      await store.toggleFavorite(25);

      expect(store.isFavorite(25), isTrue);
      expect(
        await preferences.getStringList('favorite_pokemon_ids'),
        ['25'],
      );
    });

    test('removing a favorite updates and persists it', () async {
      await store.toggleFavorite(25);
      await store.toggleFavorite(25);

      expect(store.isFavorite(25), isFalse);
      expect(
        await preferences.getStringList('favorite_pokemon_ids'),
        isEmpty,
      );
    });

    test('rejects invalid Pokémon IDs', () async {
      await expectLater(
        store.toggleFavorite(0),
        throwsArgumentError,
      );

      expect(store.favoriteIds, isEmpty);
    });
  });
}