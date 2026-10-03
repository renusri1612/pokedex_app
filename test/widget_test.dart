import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokedex_app/main.dart';
import 'package:pokedex_app/screens/favorites_screen.dart';
import 'package:pokedex_app/screens/pokemon_list_screen.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';
import 'package:pokedex_app/state/favorites_scope.dart';
import 'package:pokedex_app/state/favorites_store.dart';

class FakePreferences implements FavoritesPreferences {
  final Map<String, List<String>> _data = {};

  @override
  Future<List<String>?> getStringList(String key) async => _data[key]?.toList();

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _data[key] = value.toList();
  }
}

PokemonApiService _fakeApiService() => PokemonApiService(
  client: MockClient((request) async {
    if (request.url.path.endsWith('/pokemon/1')) {
      return http.Response(
        '{"id":1,"name":"bulbasaur","height":7,"weight":69,"types":[{"type":{"name":"grass"}}],"abilities":[{"ability":{"name":"overgrow"}}],"stats":[{"base_stat":45,"stat":{"name":"hp"}}],"sprites":{"front_default":null}}',
        200,
      );
    }
    if (request.url.path.endsWith('/pokemon/2')) {
      return http.Response(
        '{"id":2,"name":"ivysaur","height":10,"weight":130,"types":[{"type":{"name":"grass"}},{"type":{"name":"poison"}}],"abilities":[{"ability":{"name":"chlorophyll"}}],"stats":[{"base_stat":60,"stat":{"name":"hp"}}],"sprites":{"front_default":null}}',
        200,
      );
    }
    if (request.url.queryParameters['offset'] == '1') {
      return http.Response(
        '{"results":[{"name":"ivysaur","url":"https://pokeapi.co/api/v2/pokemon/2/"}]}',
        200,
      );
    }
    return http.Response(
      '{"results":[{"name":"bulbasaur","url":"https://pokeapi.co/api/v2/pokemon/1/"},{"name":"ivysaur","url":"https://pokeapi.co/api/v2/pokemon/2/"}]}',
      200,
    );
  }),
);

void main() {
  testWidgets('Pok\u00e9dex app displays its home screen', (tester) async {
    final FavoritesStore store = FavoritesStore(preferences: FakePreferences());

    await tester.pumpWidget(
      PokedexApp(favoritesStore: store, apiServiceFactory: _fakeApiService),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar).first,
        matching: find.text('Pok\u00e9dex'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('list tap opens details for the selected Pok\u00e9mon', (
    tester,
  ) async {
    final FavoritesStore store = FavoritesStore(preferences: FakePreferences());
    await store.loadFavorites();

    await tester.pumpWidget(
      FavoritesScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: PokemonListScreen(apiServiceFactory: _fakeApiService),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ivysaur'));
    await tester.pumpAndSettle();

    expect(find.text('#2 Ivysaur'), findsOneWidget);
    expect(find.text('Grass'), findsOneWidget);
    expect(find.text('Poison'), findsOneWidget);
    expect(find.text('Chlorophyll'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('Favorites tap opens details for the selected Pok\u00e9mon', (
    tester,
  ) async {
    final FakePreferences preferences = FakePreferences();
    await preferences.setStringList('favorite_pokemon_ids', ['2']);
    final FavoritesStore store = FavoritesStore(preferences: preferences);
    await store.loadFavorites();

    await tester.pumpWidget(
      FavoritesScope(
        store: store,
        child: MaterialApp(
          home: FavoritesScreen(apiServiceFactory: _fakeApiService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ivysaur'));
    await tester.pumpAndSettle();

    expect(find.text('#2 Ivysaur'), findsOneWidget);
    expect(find.text('Grass'), findsOneWidget);
    expect(find.text('Poison'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
