import 'package:flutter/material.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';
import 'package:pokedex_app/state/favorites_scope.dart';
import 'package:pokedex_app/screens/pokemon_detail_screen.dart';

class PokemonListScreen extends StatefulWidget {
  const PokemonListScreen({super.key, this.apiServiceFactory});

  final PokemonApiService Function()? apiServiceFactory;

  @override
  State<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  late final PokemonApiService _apiService =
      widget.apiServiceFactory?.call() ?? PokemonApiService();

  final List<Pokemon> _pokemon = [];
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _hasError = false;
  bool _hasMore = true;

  int _offset = 0;

  static const int _pageSize = 20;
  List<Pokemon> get _filteredPokemon {
    final String query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _pokemon;
    }

    return _pokemon
        .where((pokemon) => pokemon.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  Future<void> _loadPokemon() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final List<Pokemon> newPokemon = await _apiService.fetchPokemonPage(
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted) return;

      setState(() {
        final Set<int> existingIds = _pokemon
            .map((pokemon) => pokemon.id)
            .toSet();
        for (final Pokemon pokemon in newPokemon) {
          if (existingIds.add(pokemon.id)) {
            _pokemon.add(pokemon);
          }
        }
        // The API offset counts returned rows, including any duplicate IDs.
        _offset += newPokemon.length;
        _hasMore = newPokemon.length == _pageSize;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pokemon.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pokemon.isEmpty && _hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48),
            const SizedBox(height: 12),
            const Text('Could not load Pokémon.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadPokemon,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_pokemon.isEmpty) {
      return const Center(child: Text('No Pokémon found.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search Pokémon...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Search covers Pokémon loaded so far. Load more to search additional Pokémon.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ),
        Expanded(
          child: _filteredPokemon.isEmpty
              ? Center(
                  child: Text(
                    _hasMore
                        ? 'No loaded Pokemon match. Load more Pokemon to search further.'
                        : 'No Pokemon match your search.',
                    textAlign: TextAlign.center,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final List<Pokemon> visiblePokemon = _filteredPokemon;
                    final double width = constraints.maxWidth;
                    final int columnCount = width >= 1280
                        ? 4
                        : width >= 980
                        ? 3
                        : width >= 560
                        ? 2
                        : 1;

                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columnCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: visiblePokemon.length,
                      itemBuilder: (context, index) {
                        final Pokemon pokemon = visiblePokemon[index];
                        final favoritesStore = FavoritesScope.of(context);

                        return _PokemonCard(
                          pokemon: pokemon,
                          isFavorite: favoritesStore.isFavorite(pokemon.id),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PokemonDetailScreen(
                                pokemon: pokemon,
                                apiServiceFactory: widget.apiServiceFactory,
                              ),
                            ),
                          ),
                          onToggleFavorite: () {
                            favoritesStore.toggleFavorite(pokemon.id);
                          },
                        );
                      },
                    );
                  },
                ),
        ),
        if (_hasError)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Could not load more Pokémon.'),
          ),
        if (_hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextButton(
              onPressed: _loadPokemon,
              child: const Text('Retry loading more'),
            ),
          ),
        if (_hasMore && !_hasError)
          Padding(
            padding: const EdgeInsets.all(12),
            child: _isLoading
                ? const CircularProgressIndicator()
                : FilledButton(
                    onPressed: _loadPokemon,
                    child: const Text('Load More Pokémon'),
                  ),
          ),
      ],
    );
  }
}

class _PokemonCard extends StatefulWidget {
  const _PokemonCard({
    required this.pokemon,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Pokemon pokemon;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  State<_PokemonCard> createState() => _PokemonCardState();
}

class _PokemonCardState extends State<_PokemonCard> {
  bool _isHovered = false;
  bool _hasKeyboardFocus = false;

  @override
  Widget build(BuildContext context) {
    final bool isEmphasized = _isHovered || _hasKeyboardFocus;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Pokemon pokemon = widget.pokemon;

    return AnimatedContainer(
      key: ValueKey<String>('pokemon-card-${pokemon.id}'),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, isEmphasized ? -4 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isEmphasized
            ? [
                BoxShadow(
                  color: colors.primary.withAlpha(35),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ]
            : const [],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (isHovered) {
            if (_isHovered != isHovered) {
              setState(() => _isHovered = isHovered);
            }
          },
          onFocusChange: (hasFocus) {
            if (_hasKeyboardFocus != hasFocus) {
              setState(() => _hasKeyboardFocus = hasFocus);
            }
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: widget.isFavorite
                      ? 'Remove favorite'
                      : 'Add favorite',
                  icon: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: widget.isFavorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: widget.onToggleFavorite,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Image.network(
                    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.catching_pokemon, size: 64);
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  pokemon.name[0].toUpperCase() + pokemon.name.substring(1),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
