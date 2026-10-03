import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/screens/pokemon_detail_screen.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';
import 'package:pokedex_app/state/favorites_scope.dart';
import 'package:pokedex_app/state/favorites_store.dart';

class _FakePreferences implements FavoritesPreferences {
  @override
  Future<List<String>?> getStringList(String key) async => null;

  @override
  Future<void> setStringList(String key, List<String> value) async {}
}

void main() {
  testWidgets('detail request shows loading, error, and retry success', (
    tester,
  ) async {
    final FavoritesStore store = FavoritesStore(
      preferences: _FakePreferences(),
    );
    await store.loadFavorites();
    int requestCount = 0;

    PokemonApiService apiServiceFactory() => PokemonApiService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v2/pokemon/25');
        requestCount++;
        if (requestCount == 1) {
          return http.Response('Temporary server error', 500);
        }
        return http.Response(
          jsonEncode({
            'id': 25,
            'name': 'pikachu',
            'height': 4,
            'weight': 60,
            'types': [
              {
                'type': {'name': 'electric'},
              },
            ],
            'abilities': [],
            'stats': [],
            'sprites': {},
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      FavoritesScope(
        store: store,
        child: MaterialApp(
          home: PokemonDetailScreen(
            pokemon: const Pokemon(
              id: 25,
              name: 'pikachu',
              url: 'https://pokeapi.co/api/v2/pokemon/25/',
            ),
            apiServiceFactory: apiServiceFactory,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Could not load Pokémon details.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('#25 Pikachu'), findsOneWidget);
    expect(find.text('Electric'), findsOneWidget);
    expect(requestCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
