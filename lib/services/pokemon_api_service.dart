import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokedex_app/models/pokemon.dart';

class PokemonApiService {
  static const String _baseUrl = 'https://pokeapi.co/api/v2';

  final http.Client _client;

  PokemonApiService({http.Client? client}) : _client = client ?? http.Client();

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

    final http.Response response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load Pokémon: HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;

    final List<dynamic> results = json['results'] as List<dynamic>;

    return results
        .map((result) => Pokemon.fromApiResult(result as Map<String, dynamic>))
        .toList();
  }

  void dispose() {
    _client.close();
  }
}
