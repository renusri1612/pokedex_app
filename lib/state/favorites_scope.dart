import 'package:flutter/widgets.dart';
import 'package:pokedex_app/state/favorites_store.dart';

class FavoritesScope extends InheritedNotifier<FavoritesStore> {
  const FavoritesScope({
    super.key,
    required FavoritesStore store,
    required super.child,
  }) : super(notifier: store);

  static FavoritesStore of(BuildContext context) {
    final FavoritesScope? scope = context
        .dependOnInheritedWidgetOfExactType<FavoritesScope>();

    assert(scope != null, 'No FavoritesScope found in the widget tree.');

    return scope!.notifier!;
  }
}
