import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/main.dart';
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
  testWidgets('Pokédex app displays its home screen', (tester) async {
    final FavoritesStore store = FavoritesStore(preferences: FakePreferences());

    await tester.pumpWidget(PokedexApp(favoritesStore: store));

    await tester.pumpAndSettle();

    expect(find.text('Pokédex'), findsOneWidget);
    expect(find.text('Your Pokédex adventure starts here!'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
