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

    expect(find.text('#025'), findsOneWidget);
    expect(find.text('Electric'), findsOneWidget);
    expect(requestCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('detail content scrolls on a compact browser viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FavoritesStore store = FavoritesStore(
      preferences: _FakePreferences(),
    );
    await store.loadFavorites();
    final PokemonApiService service = PokemonApiService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'id': 6,
            'name': 'charizard',
            'height': 17,
            'weight': 905,
            'types': [
              {
                'type': {'name': 'fire'},
              },
              {
                'type': {'name': 'flying'},
              },
            ],
            'abilities': [
              {
                'ability': {'name': 'blaze'},
              },
              {
                'ability': {'name': 'solar-power'},
              },
            ],
            'stats': [
              {
                'base_stat': 78,
                'stat': {'name': 'hp'},
              },
              {
                'base_stat': 84,
                'stat': {'name': 'attack'},
              },
              {
                'base_stat': 78,
                'stat': {'name': 'defense'},
              },
              {
                'base_stat': 109,
                'stat': {'name': 'special-attack'},
              },
              {
                'base_stat': 85,
                'stat': {'name': 'special-defense'},
              },
              {
                'base_stat': 100,
                'stat': {'name': 'speed'},
              },
            ],
            'sprites': {},
          }),
          200,
        ),
      ),
    );

    await tester.pumpWidget(
      FavoritesScope(
        store: store,
        child: MaterialApp(
          home: PokemonDetailScreen(
            pokemon: const Pokemon(
              id: 6,
              name: 'charizard',
              url: 'https://pokeapi.co/api/v2/pokemon/6/',
            ),
            apiServiceFactory: () => service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('#006'), findsOneWidget);
    expect(find.text('Charizard'), findsNWidgets(2));
    expect(find.text('Fire'), findsOneWidget);
    expect(find.text('Flying'), findsOneWidget);
    expect(find.text('1.7 m'), findsOneWidget);
    expect(find.text('90.5 kg'), findsOneWidget);
    expect(find.text('Blaze'), findsOneWidget);
    expect(find.text('Solar Power'), findsOneWidget);
    expect(find.text('Base stats'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pokemon-stats-radar-chart')),
      findsOneWidget,
    );
    expect(find.text('HP'), findsOneWidget);
    expect(find.text('Attack'), findsOneWidget);
    expect(find.text('Defense'), findsOneWidget);
    expect(find.text('Special Attack'), findsOneWidget);
    expect(find.text('Special Defense'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('109'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.textContaining('Scale: 0–255'), findsOneWidget);

    final Rect compactHeight = tester.getRect(
      find.byKey(const ValueKey('measurement-height')),
    );
    final Rect compactWeight = tester.getRect(
      find.byKey(const ValueKey('measurement-weight')),
    );
    expect(compactHeight.bottom, lessThan(compactWeight.top));

    tester.view.physicalSize = const Size(1000, 1000);
    await tester.pumpAndSettle();
    final Rect wideHeight = tester.getRect(
      find.byKey(const ValueKey('measurement-height')),
    );
    final Rect wideWeight = tester.getRect(
      find.byKey(const ValueKey('measurement-weight')),
    );
    expect(wideHeight.right, lessThanOrEqualTo(wideWeight.left));

    await tester.ensureVisible(find.text('Speed'));
    await tester.pumpAndSettle();
    expect(find.text('Speed'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
