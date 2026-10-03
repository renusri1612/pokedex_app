import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokedex_app/models/pokemon.dart';

class PokemonApiException implements Exception {
  const PokemonApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PokemonApiTimeoutException implements Exception {
  const PokemonApiTimeoutException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PokemonApiService {
  static const String _baseUrl = 'https://pokeapi.co/api/v2';
  static const Duration defaultTimeout = Duration(seconds: 15);

  final Duration _timeout;
  final http.Client _client;

  PokemonApiService({http.Client? client, Duration timeout = defaultTimeout})
    : _timeout = _validateTimeout(timeout),
      _client = client ?? http.Client();

  static Duration _validateTimeout(Duration timeout) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive.');
    }
    return timeout;
  }

  Future<List<Pokemon>> fetchPokemonPage({
    int limit = 20,
    int offset = 0,
  }) async {
    if (limit <= 0 || offset < 0) {
      throw ArgumentError(
        'Limit must be positive and offset cannot be negative.',
      );
    }

    final Uri uri = Uri.parse('$_baseUrl/pokemon?limit=$limit&offset=$offset');
    final http.Response response = await _get(uri);
    _requireSuccess(response, 'Pokémon list');

    final Object? decoded = _decodeJson(response.body);
    if (decoded is! Map || decoded['results'] is! List) {
      throw const FormatException(
        'PokéAPI returned an invalid Pokémon list response.',
      );
    }

    final List<dynamic> results = decoded['results'] as List<dynamic>;
    return results.indexed.map((entry) {
      final (int index, Object? result) = entry;
      if (result is! Map) {
        throw FormatException(
          'PokéAPI Pokémon list item $index is not an object.',
        );
      }
      return Pokemon.fromApiResult(Map<String, dynamic>.from(result));
    }).toList();
  }

  Future<Pokemon> fetchPokemonDetails(String nameOrId) async {
    final String key = nameOrId.trim().toLowerCase();
    if (key.isEmpty) throw ArgumentError.value(nameOrId, 'nameOrId');

    final Uri uri = Uri.parse('$_baseUrl/pokemon/${Uri.encodeComponent(key)}');
    final http.Response response = await _get(uri);
    if (response.statusCode == 404) {
      throw PokemonApiException(
        'Pokémon "$key" was not found.',
        statusCode: response.statusCode,
      );
    }
    _requireSuccess(response, 'Pokémon details');

    final Object? decoded = _decodeJson(response.body);
    if (decoded is! Map) {
      throw const FormatException(
        'PokéAPI returned an invalid Pokémon details response.',
      );
    }
    return Pokemon.fromDetails(Map<String, dynamic>.from(decoded));
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw PokemonApiTimeoutException(
        'PokéAPI request timed out after ${_timeout.inMilliseconds} ms.',
      );
    }
  }

  void _requireSuccess(http.Response response, String operation) {
    if (response.statusCode != 200) {
      throw PokemonApiException(
        'Could not load $operation: HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
  }

  Object? _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw FormatException(
        'PokéAPI returned malformed JSON: ${error.message}',
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
