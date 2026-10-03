import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';

const String _detailsJson = '''
{
  "id": 25,
  "name": "pikachu",
  "height": 4,
  "weight": 60,
  "types": [{"type": {"name": "electric"}}],
  "abilities": [{"ability": {"name": "static"}}],
  "stats": [{"base_stat": 35, "stat": {"name": "hp"}}],
  "sprites": {"front_default": "https://img.test/pikachu.png"}
}
''';

http.Response _listResponse() => http.Response(
  jsonEncode({
    'results': [
      {'name': 'bulbasaur', 'url': 'https://pokeapi.co/api/v2/pokemon/1/'},
      {'name': 'pikachu', 'url': 'https://pokeapi.co/api/v2/pokemon/25/'},
    ],
  }),
  200,
);

void main() {
  group('PokemonApiService', () {
    test('fetches and parses a valid Pokémon page', () async {
      final PokemonApiService service = PokemonApiService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/pokemon');
          expect(request.url.queryParameters['limit'], '2');
          expect(request.url.queryParameters['offset'], '20');
          return _listResponse();
        }),
      );

      final List<Pokemon> pokemon = await service.fetchPokemonPage(
        limit: 2,
        offset: 20,
      );

      expect(pokemon.map((item) => item.name), ['bulbasaur', 'pikachu']);
      expect(pokemon.map((item) => item.id), [1, 25]);
      service.dispose();
    });

    test('fetches and parses valid Pokémon details', () async {
      final PokemonApiService service = PokemonApiService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v2/pokemon/pikachu');
          return http.Response(_detailsJson, 200);
        }),
      );

      final Pokemon pokemon = await service.fetchPokemonDetails(' Pikachu ');

      expect(pokemon.id, 25);
      expect(pokemon.name, 'pikachu');
      expect(pokemon.types, ['electric']);
      expect(pokemon.abilities, ['static']);
      service.dispose();
    });

    test('represents list HTTP errors with status information', () async {
      final PokemonApiService service = PokemonApiService(
        client: MockClient((_) async => http.Response('Server error', 500)),
      );

      await expectLater(
        service.fetchPokemonPage(),
        throwsA(
          isA<PokemonApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
      service.dispose();
    });

    test('reports a Pokémon detail 404 clearly', () async {
      final PokemonApiService service = PokemonApiService(
        client: MockClient((_) async => http.Response('Not found', 404)),
      );

      await expectLater(
        service.fetchPokemonDetails('missingno'),
        throwsA(
          isA<PokemonApiException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having(
                (error) => error.message,
                'message',
                contains('not found'),
              ),
        ),
      );
      service.dispose();
    });

    test('reports malformed JSON for list and detail responses', () async {
      final PokemonApiService service = PokemonApiService(
        client: MockClient((_) async => http.Response('{broken json', 200)),
      );

      await expectLater(
        service.fetchPokemonPage(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('malformed JSON'),
          ),
        ),
      );
      await expectLater(
        service.fetchPokemonDetails('pikachu'),
        throwsA(isA<FormatException>()),
      );
      service.dispose();
    });

    test(
      'rejects invalid page structures and non-object result items',
      () async {
        final List<String> bodies = ['[]', '{"results":{}}', '{"results":[7]}'];
        for (final String body in bodies) {
          final PokemonApiService service = PokemonApiService(
            client: MockClient((_) async => http.Response(body, 200)),
          );

          await expectLater(
            service.fetchPokemonPage(),
            throwsA(isA<FormatException>()),
          );
          service.dispose();
        }
      },
    );

    test('rejects a non-object detail response', () async {
      final PokemonApiService service = PokemonApiService(
        client: MockClient((_) async => http.Response('[]', 200)),
      );

      await expectLater(
        service.fetchPokemonDetails('pikachu'),
        throwsA(isA<FormatException>()),
      );
      service.dispose();
    });

    test('reports a request timeout distinctly', () async {
      final Completer<http.Response> pendingResponse =
          Completer<http.Response>();
      final PokemonApiService service = PokemonApiService(
        client: MockClient((_) => pendingResponse.future),
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.fetchPokemonPage(),
        throwsA(isA<PokemonApiTimeoutException>()),
      );

      pendingResponse.complete(_listResponse());
      service.dispose();
    });

    test('rejects invalid pagination values and timeout durations', () async {
      final PokemonApiService service = PokemonApiService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(() => service.fetchPokemonPage(limit: 0), throwsArgumentError);
      expect(() => service.fetchPokemonPage(offset: -1), throwsArgumentError);
      expect(
        () => PokemonApiService(timeout: Duration.zero),
        throwsArgumentError,
      );
      service.dispose();
    });
  });
}
