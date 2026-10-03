import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_app/models/pokemon.dart';

void main() {
  group('Pokemon model', () {
    test('parses a valid Pokémon list result', () {
      final Pokemon pokemon = Pokemon.fromApiResult({
        'name': 'bulbasaur',
        'url': 'https://pokeapi.co/api/v2/pokemon/1/',
      });

      expect(pokemon.id, 1);
      expect(pokemon.name, 'bulbasaur');
      expect(pokemon.url, 'https://pokeapi.co/api/v2/pokemon/1/');
    });

    test('rejects missing and wrongly typed required list fields', () {
      expect(
        () => Pokemon.fromApiResult({'url': 'https://pokeapi.co/pokemon/1/'}),
        throwsFormatException,
      );
      expect(
        () => Pokemon.fromApiResult({'name': 'pikachu', 'url': 25}),
        throwsFormatException,
      );
      expect(
        () => Pokemon.fromApiResult({'name': 'pikachu', 'url': 'not a URL'}),
        throwsFormatException,
      );
      expect(
        () => Pokemon.fromApiResult({
          'name': 'pikachu',
          'url': 'https://pokeapi.co/pokemon/zero/',
        }),
        throwsFormatException,
      );
    });

    test('parses valid detail fields used by the detail screen', () {
      final Pokemon pokemon = Pokemon.fromDetails({
        'id': 25,
        'name': 'pikachu',
        'height': 4,
        'weight': 60,
        'types': [
          {
            'type': {'name': 'electric'},
          },
        ],
        'abilities': [
          {
            'ability': {'name': 'static'},
          },
        ],
        'stats': [
          {
            'base_stat': 35,
            'stat': {'name': 'hp'},
          },
        ],
        'sprites': {
          'other': {
            'official-artwork': {
              'front_default': 'https://img.test/pikachu.png',
            },
          },
          'front_default': 'https://img.test/pikachu-small.png',
        },
      });

      expect(pokemon.id, 25);
      expect(pokemon.name, 'pikachu');
      expect(pokemon.height, 4);
      expect(pokemon.weight, 60);
      expect(pokemon.types, ['electric']);
      expect(pokemon.abilities, ['static']);
      expect(pokemon.stats, {'hp': 35});
      expect(pokemon.imageUrl, 'https://img.test/pikachu.png');
    });

    test('defaults missing optional details without inventing values', () {
      final Pokemon pokemon = Pokemon.fromDetails({
        'id': 25,
        'name': 'pikachu',
      });

      expect(pokemon.height, isNull);
      expect(pokemon.weight, isNull);
      expect(pokemon.imageUrl, isNull);
      expect(pokemon.types, isEmpty);
      expect(pokemon.abilities, isEmpty);
      expect(pokemon.stats, isEmpty);
    });

    test('rejects missing or wrongly typed required detail fields', () {
      expect(
        () => Pokemon.fromDetails({'name': 'pikachu'}),
        throwsFormatException,
      );
      expect(
        () => Pokemon.fromDetails({'id': '25', 'name': 'pikachu'}),
        throwsFormatException,
      );
      expect(
        () => Pokemon.fromDetails({'id': 25, 'name': null}),
        throwsFormatException,
      );
    });

    test('rejects malformed optional fields instead of hiding bad data', () {
      expect(
        () => Pokemon.fromDetails({
          'id': 25,
          'name': 'pikachu',
          'types': 'electric',
        }),
        throwsFormatException,
      );
      expect(
        () => Pokemon.fromDetails({
          'id': 25,
          'name': 'pikachu',
          'height': 'four',
        }),
        throwsFormatException,
      );
      expect(
        () => Pokemon.fromDetails({
          'id': 25,
          'name': 'pikachu',
          'stats': [null],
        }),
        throwsFormatException,
      );
    });
  });
}
