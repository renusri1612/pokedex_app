import 'package:flutter/material.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';

class PokemonListScreen extends StatefulWidget {
  const PokemonListScreen({super.key});

  @override
  State<PokemonListScreen> createState() => _PokemonListScreenState();
}

class _PokemonListScreenState extends State<PokemonListScreen> {
  final PokemonApiService _apiService = PokemonApiService();

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
        _pokemon.addAll(newPokemon);
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
        Expanded(
          child: _filteredPokemon.isEmpty
              ? const Center(child: Text('No Pokémon match your search.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _filteredPokemon.length,
                  itemBuilder: (context, index) {
                    final Pokemon pokemon = _filteredPokemon[index];

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Image.network(
                              'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.catching_pokemon,
                                  size: 64,
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              pokemon.name[0].toUpperCase() +
                                  pokemon.name.substring(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (_hasError)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Could not load more Pokémon.'),
          ),
        if (_hasMore)
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
