
import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/models/pokemon.dart';

void main() {
  group('Pokemon model', () {
    test('converts API data into a Pokemon object', () {
      final Map<String, dynamic> json = {
        'name': 'bulbasaur',
        'url': 'https://pokeapi.co/api/v2/pokemon/1/',
      };

      final Pokemon pokemon = Pokemon.fromApiResult(json);

      expect(pokemon.id, 1);
      expect(pokemon.name, 'bulbasaur');
      expect(
        pokemon.url,
        'https://pokeapi.co/api/v2/pokemon/1/',
      );
    });

    test('extracts the correct ID from a Pokémon URL', () {
      final Map<String, dynamic> json = {
        'name': 'pikachu',
        'url': 'https://pokeapi.co/api/v2/pokemon/25/',
      };

      final Pokemon pokemon = Pokemon.fromApiResult(json);

      expect(pokemon.id, 25);
      expect(pokemon.name, 'pikachu');
    });
  });
}