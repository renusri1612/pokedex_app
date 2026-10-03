import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/screens/pokemon_detail_screen.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';
import 'package:pokedex_app/state/favorites_scope.dart';
import 'package:pokedex_app/state/favorites_store.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.apiServiceFactory});

  final PokemonApiService Function()? apiServiceFactory;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final Map<int, Pokemon> _pokemonById = {};
  final List<Pokemon> _favoritePokemon = [];

  FavoritesStore? _favoritesStore;
  PokemonApiService? _apiService;
  Set<int>? _requestedIds;
  Object? _loadError;
  int _requestVersion = 0;
  bool _isLoading = true;

  PokemonApiService get _service =>
      _apiService ??= widget.apiServiceFactory?.call() ?? PokemonApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final FavoritesStore store = FavoritesScope.of(context);
    if (!identical(store, _favoritesStore)) {
      _favoritesStore?.removeListener(_handleFavoritesChanged);
      _favoritesStore = store;
      _favoritesStore!.addListener(_handleFavoritesChanged);
      _requestedIds = null;
      _pokemonById.clear();
    }
    _syncFavorites();
  }

  @override
  void dispose() {
    _favoritesStore?.removeListener(_handleFavoritesChanged);
    _apiService?.dispose();
    super.dispose();
  }

  void _handleFavoritesChanged() => _syncFavorites();

  bool _sameIds(Set<int> first, Set<int> second) =>
      first.length == second.length && first.containsAll(second);

  void _syncFavorites({bool force = false}) {
    final Set<int> ids = _favoritesStore!.favoriteIds;
    if (!force && _requestedIds != null && _sameIds(ids, _requestedIds!)) {
      return;
    }

    _requestedIds = ids;
    final int requestVersion = ++_requestVersion;
    if (ids.isEmpty) {
      setState(() {
        _favoritePokemon.clear();
        _loadError = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _loadError = null;
      _isLoading = true;
    });
    unawaited(_loadFavorites(ids, requestVersion));
  }

  Future<void> _loadFavorites(Set<int> ids, int requestVersion) async {
    try {
      final List<int> missingIds = ids
          .where((id) => !_pokemonById.containsKey(id))
          .toList();
      final List<Pokemon> loadedPokemon = await Future.wait(
        missingIds.map((id) => _service.fetchPokemonDetails(id.toString())),
      );

      if (!mounted || requestVersion != _requestVersion) return;

      for (final Pokemon pokemon in loadedPokemon) {
        _pokemonById[pokemon.id] = pokemon;
      }
      setState(() {
        _favoritePokemon
          ..clear()
          ..addAll(ids.map((id) => _pokemonById[id]!).toList());
        _loadError = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final FavoritesStore favoritesStore = _favoritesStore!;

    return Scaffold(
      appBar: AppBar(title: const Text('My Favorites')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48),
                    const SizedBox(height: 12),
                    Text('Could not load favorites: $_loadError'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _syncFavorites(force: true),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _favoritePokemon.isEmpty
          ? const Center(child: Text('No favorite Pokémon yet!'))
          : ListView.builder(
              itemCount: _favoritePokemon.length,
              itemBuilder: (context, index) {
                final Pokemon pokemon = _favoritePokemon[index];

                return ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PokemonDetailScreen(
                        pokemon: pokemon,
                        apiServiceFactory: widget.apiServiceFactory,
                      ),
                    ),
                  ),
                  leading: Image.network(
                    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
                    width: 60,
                    height: 60,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.catching_pokemon, size: 40);
                    },
                  ),
                  title: Text(
                    pokemon.name[0].toUpperCase() + pokemon.name.substring(1),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    tooltip: 'Remove favorite',
                    onPressed: () async {
                      await favoritesStore.toggleFavorite(pokemon.id);
                    },
                  ),
                );
              },
            ),
    );
  }
}
