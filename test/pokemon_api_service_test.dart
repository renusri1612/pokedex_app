
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';

void main() {
  group('PokemonApiService', () {
    test('fetches a page and converts the results', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v2/pokemon');
        expect(request.url.queryParameters['limit'], '2');
        expect(request.url.queryParameters['offset'], '20');

        return http.Response(
          jsonEncode({
            'results': [
              {
                'name': 'bulbasaur',
                'url': 'https://pokeapi.co/api/v2/pokemon/1/',
              },
              {
                'name': 'ivysaur',
                'url': 'https://pokeapi.co/api/v2/pokemon/2/',
              },
            ],
          }),
          200,
        );
      });

      final service = PokemonApiService(client: client);

      final pokemon = await service.fetchPokemonPage(
        limit: 2,
        offset: 20,
      );

      expect(pokemon.length, 2);
      expect(pokemon[0].name, 'bulbasaur');
      expect(pokemon[0].id, 1);
      expect(pokemon[1].name, 'ivysaur');
      expect(pokemon[1].id, 2);

      service.dispose();
    });

    test('throws an exception when the API returns an error', () async {
      final client = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final service = PokemonApiService(client: client);

      expect(
        () => service.fetchPokemonPage(),
        throwsA(isA<Exception>()),
      );

      service.dispose();
    });

    test('rejects invalid pagination values', () async {
      final client = MockClient((request) async {
        return http.Response('{}', 200);
      });

      final service = PokemonApiService(client: client);

      expect(
        () => service.fetchPokemonPage(limit: 0),
        throwsArgumentError,
      );

      expect(
        () => service.fetchPokemonPage(offset: -1),
        throwsArgumentError,
      );

      service.dispose();
    });
  });
}