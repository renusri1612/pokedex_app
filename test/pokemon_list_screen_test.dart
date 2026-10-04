import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokedex_app/screens/pokemon_list_screen.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';
import 'package:pokedex_app/state/favorites_scope.dart';
import 'package:pokedex_app/state/favorites_store.dart';

class _FakePreferences implements FavoritesPreferences {
  @override
  Future<List<String>?> getStringList(String key) async => null;

  @override
  Future<void> setStringList(String key, List<String> value) async {}
}

List<Map<String, Object>> _page(Iterable<(int, String)> pokemon) => pokemon
    .map(
      (entry) => {
        'name': entry.$2,
        'url': 'https://pokeapi.co/api/v2/pokemon/${entry.$1}/',
      },
    )
    .toList();

List<(int, String)> _firstPage() => List<(int, String)>.generate(
  20,
  (index) => (index + 1, 'pokemon${index + 1}'),
);

http.Response _response(Iterable<(int, String)> pokemon) =>
    http.Response(jsonEncode({'results': _page(pokemon)}), 200);

Future<FavoritesStore> _showList(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) respond,
) async {
  final FavoritesStore store = FavoritesStore(preferences: _FakePreferences());
  await store.loadFavorites();
  await tester.pumpWidget(
    FavoritesScope(
      store: store,
      child: MaterialApp(
        home: Scaffold(
          body: PokemonListScreen(
            apiServiceFactory: () =>
                PokemonApiService(client: MockClient(respond)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> _closeList(WidgetTester tester, FavoritesStore store) async {
  await tester.pumpWidget(const SizedBox.shrink());
  store.dispose();
}

void main() {
  testWidgets('grid column count adapts to available width', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final FavoritesStore store = await _showList(
      tester,
      (_) async => _response(_firstPage()),
    );

    int columns() =>
        (tester.widget<GridView>(find.byType(GridView)).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount;

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(columns(), 4);

    tester.view.physicalSize = const Size(1024, 800);
    await tester.pumpAndSettle();
    expect(columns(), 3);

    tester.view.physicalSize = const Size(800, 800);
    await tester.pumpAndSettle();
    expect(columns(), 2);

    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpAndSettle();
    expect(columns(), 1);

    await _closeList(tester, store);
  });

  testWidgets('hover animates card without blocking favorite or detail taps', (
    tester,
  ) async {
    final FavoritesStore store = await _showList(
      tester,
      (_) async => _response(_firstPage()),
    );
    final Finder card = find.byKey(const ValueKey('pokemon-card-1'));
    final Rect beforeHover = tester.getRect(card);
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(beforeHover.center);
    await tester.pump(const Duration(milliseconds: 200));

    final Rect afterHover = tester.getRect(card);
    final AnimatedContainer animatedCard = tester.widget<AnimatedContainer>(
      card,
    );
    expect(animatedCard.transform!.storage[13], -4);
    expect(afterHover.width, beforeHover.width);

    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip('Add favorite')),
    );
    await tester.pump();
    expect(store.isFavorite(1), isTrue);
    expect(find.byType(GridView), findsOneWidget);

    await tester.tap(find.text('Pokemon1'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Pokemon1')),
      findsOneWidget,
    );

    await mouse.removePointer();
    await _closeList(tester, store);
  });

  testWidgets('search trims whitespace and ignores letter case', (
    tester,
  ) async {
    final FavoritesStore store = await _showList(
      tester,
      (_) async => _response([(1, 'bulbasaur'), ..._firstPage().skip(1)]),
    );

    await tester.enterText(find.byType(TextField), '  BASA  ');
    await tester.pump();

    expect(find.text('Bulbasaur'), findsOneWidget);
    expect(find.text('Pokemon2'), findsNothing);

    await _closeList(tester, store);
  });

  testWidgets('clearing search shows all loaded Pokemon', (tester) async {
    final FavoritesStore store = await _showList(
      tester,
      (_) async => _response(_firstPage()),
    );

    await tester.enterText(find.byType(TextField), 'no-such-pokemon');
    await tester.pump();
    expect(find.text('Pokemon1'), findsNothing);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.text('Pokemon1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Pokemon1'), findsOneWidget);

    await _closeList(tester, store);
  });

  testWidgets('search includes Pokemon loaded from a later page', (
    tester,
  ) async {
    final FavoritesStore store = await _showList(tester, (request) async {
      return request.url.queryParameters['offset'] == '20'
          ? _response([(21, 'targetmon')])
          : _response(_firstPage());
    });

    await tester.enterText(find.byType(TextField), 'target');
    await tester.pump();
    expect(find.text('Targetmon'), findsNothing);
    await tester.tap(find.text('Load More Pokémon'));
    await tester.pumpAndSettle();
    expect(find.text('Targetmon'), findsOneWidget);

    await _closeList(tester, store);
  });

  testWidgets('no match explains that more loaded pages can be searched', (
    tester,
  ) async {
    final FavoritesStore store = await _showList(
      tester,
      (_) async => _response(_firstPage()),
    );

    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();

    expect(
      find.text(
        'No loaded Pokemon match. Load more Pokemon to search further.',
      ),
      findsOneWidget,
    );
    expect(find.text('Load More Pokémon'), findsOneWidget);

    await _closeList(tester, store);
  });

  testWidgets('requests consecutive pages with the correct offsets', (
    tester,
  ) async {
    final List<int> offsets = [];
    final FavoritesStore store = await _showList(tester, (request) async {
      offsets.add(int.parse(request.url.queryParameters['offset']!));
      return request.url.queryParameters['offset'] == '20'
          ? _response([(21, 'pokemon21')])
          : _response(_firstPage());
    });

    await tester.tap(find.text('Load More Pokémon'));
    await tester.pumpAndSettle();

    expect(offsets, [0, 20]);
    await tester.enterText(find.byType(TextField), 'pokemon21');
    await tester.pump();
    expect(find.text('Pokemon21'), findsOneWidget);
    expect(find.text('Load More Pokémon'), findsNothing);

    await _closeList(tester, store);
  });

  testWidgets('an empty first page stops pagination', (tester) async {
    int requestCount = 0;
    final FavoritesStore store = await _showList(tester, (_) async {
      requestCount++;
      return _response([]);
    });

    expect(find.textContaining('found.'), findsOneWidget);
    expect(find.text('Load More Pokémon'), findsNothing);
    expect(requestCount, 1);

    await _closeList(tester, store);
  });

  testWidgets('overlapping IDs are displayed only once', (tester) async {
    final FavoritesStore store = await _showList(tester, (request) async {
      return request.url.queryParameters['offset'] == '20'
          ? _response([(20, 'pokemon20'), (21, 'pokemon21')])
          : _response(_firstPage());
    });

    await tester.tap(find.text('Load More Pokémon'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pokemon20');
    await tester.pump();
    expect(find.text('Pokemon20'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'pokemon21');
    await tester.pump();
    expect(find.text('Pokemon21'), findsOneWidget);

    await _closeList(tester, store);
  });

  testWidgets('later-page failure keeps records and offers retry', (
    tester,
  ) async {
    int laterPageRequests = 0;
    final FavoritesStore store = await _showList(tester, (request) async {
      if (request.url.queryParameters['offset'] == '20') {
        laterPageRequests++;
        if (laterPageRequests == 1) {
          return http.Response('temporary error', 500);
        }
        return _response([(21, 'pokemon21')]);
      }
      return _response(_firstPage());
    });

    await tester.tap(find.text('Load More Pokémon'));
    await tester.pumpAndSettle();
    expect(find.text('Pokemon1'), findsOneWidget);
    expect(find.text('Could not load more Pokémon.'), findsOneWidget);
    expect(find.text('Retry loading more'), findsOneWidget);

    await tester.tap(find.text('Retry loading more'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pokemon21');
    await tester.pump();
    expect(find.text('Pokemon21'), findsOneWidget);
    expect(laterPageRequests, 2);

    await _closeList(tester, store);
  });

  testWidgets('repeated load-more taps do not start concurrent requests', (
    tester,
  ) async {
    final Completer<http.Response> releasePage = Completer<http.Response>();
    int laterPageRequests = 0;
    final FavoritesStore store = await _showList(tester, (request) async {
      if (request.url.queryParameters['offset'] == '20') {
        laterPageRequests++;
        return releasePage.future;
      }
      return _response(_firstPage());
    });

    await tester.tap(find.text('Load More Pokémon'));
    await tester.tap(find.text('Load More Pokémon'));
    expect(laterPageRequests, 1);

    releasePage.complete(_response([(21, 'pokemon21')]));
    await tester.pumpAndSettle();
    expect(laterPageRequests, 1);
    await tester.enterText(find.byType(TextField), 'pokemon21');
    await tester.pump();
    expect(find.text('Pokemon21'), findsOneWidget);

    await _closeList(tester, store);
  });
}
