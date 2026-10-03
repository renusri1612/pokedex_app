import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokedex_app/main.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/screens/favorites_screen.dart';
import 'package:pokedex_app/screens/pokemon_detail_screen.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';
import 'package:pokedex_app/state/favorites_scope.dart';
import 'package:pokedex_app/state/favorites_store.dart';

class _FakePreferences implements FavoritesPreferences {
  final Map<String, List<String>> values = {};
  bool failWrites = false;

  @override
  Future<List<String>?> getStringList(String key) async => values[key];

  @override
  Future<void> setStringList(String key, List<String> value) async {
    if (failWrites) throw StateError('Test storage failure');
    values[key] = value.toList();
  }
}

const String _pikachuDetails =
    '{"id":25,"name":"pikachu","height":4,"weight":60,"types":[{"type":{"name":"electric"}}],"abilities":[{"ability":{"name":"static"}}],"stats":[],"sprites":{"front_default":null}}';

PokemonApiService _successfulApiService() => PokemonApiService(
  client: MockClient((request) async {
    if (request.url.path.endsWith('/pokemon/25')) {
      return http.Response(_pikachuDetails, 200);
    }
    return http.Response(
      '{"results":[{"name":"pikachu","url":"https://pokeapi.co/api/v2/pokemon/25/"}]}',
      200,
    );
  }),
);

class _DetailFavoritesTabs extends StatefulWidget {
  const _DetailFavoritesTabs({required this.pokemon});

  final Pokemon pokemon;

  @override
  State<_DetailFavoritesTabs> createState() => _DetailFavoritesTabsState();
}

class _DetailFavoritesTabsState extends State<_DetailFavoritesTabs> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          PokemonDetailScreen(
            pokemon: widget.pokemon,
            apiServiceFactory: _successfulApiService,
          ),
          FavoritesScreen(apiServiceFactory: _successfulApiService),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.info), label: 'Details'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Favorites'),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('list additions appear in Favorites and removal empties it', (
    tester,
  ) async {
    final FavoritesStore store = FavoritesStore(
      preferences: _FakePreferences(),
    );

    await tester.pumpWidget(
      PokedexApp(
        favoritesStore: store,
        apiServiceFactory: _successfulApiService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Favorites'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pikachu'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove favorite'));
    await tester.pumpAndSettle();
    expect(find.text('No favorite Pokémon yet!'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('Favorite detail failure shows an error and retry recovers', (
    tester,
  ) async {
    final _FakePreferences preferences = _FakePreferences()
      ..values['favorite_pokemon_ids'] = ['25'];
    final FavoritesStore store = FavoritesStore(preferences: preferences);
    await store.loadFavorites();
    int requestCount = 0;

    PokemonApiService apiServiceFactory() => PokemonApiService(
      client: MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response('Temporary server error', 500);
        }
        return http.Response(_pikachuDetails, 200);
      }),
    );

    await tester.pumpWidget(
      FavoritesScope(
        store: store,
        child: MaterialApp(
          home: FavoritesScreen(apiServiceFactory: apiServiceFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load favorites:'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Pikachu'), findsOneWidget);
    expect(requestCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('detail favorite changes synchronize with the Favorites tab', (
    tester,
  ) async {
    final _FakePreferences preferences = _FakePreferences()
      ..values['favorite_pokemon_ids'] = ['25'];
    final FavoritesStore store = FavoritesStore(preferences: preferences);
    await store.loadFavorites();

    await tester.pumpWidget(
      FavoritesScope(
        store: store,
        child: MaterialApp(
          home: _DetailFavoritesTabs(
            pokemon: const Pokemon(
              id: 25,
              name: 'pikachu',
              url: 'https://pokeapi.co/api/v2/pokemon/25/',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Remove favorite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('No favorite Pokémon yet!'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add favorite'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();

    expect(find.text('Pikachu'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('loads multiple favorite details concurrently', (tester) async {
    final _FakePreferences preferences = _FakePreferences()
      ..values['favorite_pokemon_ids'] = ['1', '2'];
    final FavoritesStore store = FavoritesStore(preferences: preferences);
    await store.loadFavorites();
    int activeRequests = 0;
    int maximumConcurrentRequests = 0;

    PokemonApiService apiServiceFactory() => PokemonApiService(
      client: MockClient((request) async {
        activeRequests++;
        if (activeRequests > maximumConcurrentRequests) {
          maximumConcurrentRequests = activeRequests;
        }
        await Future<void>.delayed(Duration.zero);
        activeRequests--;
        final bool isBulbasaur = request.url.path.endsWith('/pokemon/1');
        return http.Response(
          '{"id":${isBulbasaur ? 1 : 2},"name":"${isBulbasaur ? 'bulbasaur' : 'ivysaur'}","types":[],"abilities":[],"stats":[],"sprites":{}}',
          200,
        );
      }),
    );

    await tester.pumpWidget(
      FavoritesScope(
        store: store,
        child: MaterialApp(
          home: FavoritesScreen(apiServiceFactory: apiServiceFactory),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(maximumConcurrentRequests, 2);
    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('Ivysaur'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('app shows a retry action when favorite persistence fails', (
    tester,
  ) async {
    final _FakePreferences preferences = _FakePreferences()..failWrites = true;
    final FavoritesStore store = FavoritesStore(preferences: preferences);

    await tester.pumpWidget(
      PokedexApp(
        favoritesStore: store,
        apiServiceFactory: _successfulApiService,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Favorites changed but could not be saved. Retry to keep them after restart.',
      ),
      findsOneWidget,
    );
    expect(store.isFavorite(25), isTrue);

    preferences.failWrites = false;
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();

    expect(store.persistenceError, isNull);
    expect(preferences.values['favorite_pokemon_ids'], ['25']);
    expect(
      find.text(
        'Favorites changed but could not be saved. Retry to keep them after restart.',
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
