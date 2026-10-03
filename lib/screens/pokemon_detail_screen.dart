import 'package:flutter/material.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';
import 'package:pokedex_app/state/favorites_scope.dart';

class PokemonDetailScreen extends StatefulWidget {
  const PokemonDetailScreen({
    super.key,
    required this.pokemon,
    this.apiServiceFactory,
  });
  final Pokemon pokemon;
  final PokemonApiService Function()? apiServiceFactory;

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
  late final PokemonApiService _api =
      widget.apiServiceFactory?.call() ?? PokemonApiService();
  late Future<Pokemon> _details;

  @override
  void initState() {
    super.initState();
    _details = _api.fetchPokemonDetails(widget.pokemon.id.toString());
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  String _title(String value) => value
      .split('-')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title(widget.pokemon.name))),
      body: FutureBuilder<Pokemon>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load Pokémon details.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _details = _api.fetchPokemonDetails(
                          widget.pokemon.id.toString(),
                        );
                      });
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final Pokemon pokemon = snapshot.data!;
          final favorites = FavoritesScope.of(context);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Image.network(
                  pokemon.imageUrl ??
                      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
                  height: 220,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.catching_pokemon, size: 120),
                ),
              ),
              Center(
                child: Text(
                  '#${pokemon.id} ${_title(pokemon.name)}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Center(
                child: IconButton(
                  tooltip: favorites.isFavorite(pokemon.id)
                      ? 'Remove favorite'
                      : 'Add favorite',
                  iconSize: 36,
                  color: Colors.red,
                  onPressed: () => favorites.toggleFavorite(pokemon.id),
                  icon: Icon(
                    favorites.isFavorite(pokemon.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: pokemon.types
                    .map((type) => Chip(label: Text(_title(type))))
                    .toList(),
              ),
              if (pokemon.height != null || pokemon.weight != null)
                ListTile(
                  title: const Text('Measurements'),
                  subtitle: Text(
                    'Height: ${pokemon.height == null ? 'Unknown' : '${pokemon.height! / 10} m'}   Weight: ${pokemon.weight == null ? 'Unknown' : '${pokemon.weight! / 10} kg'}',
                  ),
                ),
              if (pokemon.abilities.isNotEmpty)
                ListTile(
                  title: const Text('Abilities'),
                  subtitle: Text(pokemon.abilities.map(_title).join(', ')),
                ),
              if (pokemon.stats.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Base stats',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                ...pokemon.stats.entries.map(
                  (entry) => ListTile(
                    title: Text(_title(entry.key)),
                    trailing: SizedBox(
                      width: 150,
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: (entry.value / 200).clamp(0, 1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${entry.value}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
