class Pokemon {
  final int id;
  final String name;
  final String url;
  final String? imageUrl;
  final List<String> types;
  final int? height;
  final int? weight;
  final List<String> abilities;
  final Map<String, int> stats;

  const Pokemon({
    required this.id,
    required this.name,
    required this.url,
    this.imageUrl,
    this.types = const [],
    this.height,
    this.weight,
    this.abilities = const [],
    this.stats = const {},
  });

  factory Pokemon.fromApiResult(Map<String, dynamic> json) {
    final String name = _requiredString(json, 'name');
    final String url = _requiredString(json, 'url');

    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException {
      throw const FormatException('Pokémon URL is not a valid URI.');
    }

    final List<String> segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    final int? id = segments.isEmpty ? null : int.tryParse(segments.last);
    if (!uri.hasAuthority || id == null || id <= 0) {
      throw const FormatException(
        'Pokémon URL must contain an absolute URL and a positive numeric ID.',
      );
    }

    return Pokemon(id: id, name: name, url: url);
  }

  factory Pokemon.fromDetails(Map<String, dynamic> json) {
    final Object? rawId = json['id'];
    if (rawId is! int || rawId <= 0) {
      throw const FormatException(
        'Pokémon details must contain a positive integer ID.',
      );
    }
    final String name = _requiredString(json, 'name');

    final int? height = _optionalNonNegativeInt(json, 'height');
    final int? weight = _optionalNonNegativeInt(json, 'weight');
    final List<String> types = _readNamedEntries(json, 'types', 'type');
    final List<String> abilities = _readNamedEntries(
      json,
      'abilities',
      'ability',
    );
    final Map<String, int> stats = _readStats(json['stats']);

    return Pokemon(
      id: rawId,
      name: name,
      url: 'https://pokeapi.co/api/v2/pokemon/$rawId/',
      imageUrl: _readImageUrl(json['sprites']),
      types: types,
      height: height,
      weight: weight,
      abilities: abilities,
      stats: stats,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Pokémon field "$field" must be a non-empty string.',
      );
    }
    return value;
  }

  static int? _optionalNonNegativeInt(Map<String, dynamic> json, String field) {
    final Object? value = json[field];
    if (value == null) return null;
    if (value is! int || value < 0) {
      throw FormatException(
        'Pokémon field "$field" must be a non-negative integer.',
      );
    }
    return value;
  }

  static List<String> _readNamedEntries(
    Map<String, dynamic> json,
    String field,
    String nestedField,
  ) {
    final Object? value = json[field];
    if (value == null) return const [];
    if (value is! List) {
      throw FormatException('Pokémon field "$field" must be a list.');
    }

    return value.indexed.map((entry) {
      final (int index, Object? item) = entry;
      if (item is! Map) {
        throw FormatException('Pokémon $field item $index must be an object.');
      }
      final Object? nested = item[nestedField];
      if (nested is! Map) {
        throw FormatException(
          'Pokémon $field item $index must contain "$nestedField".',
        );
      }
      final Object? name = nested['name'];
      if (name is! String || name.trim().isEmpty) {
        throw FormatException(
          'Pokémon $field item $index must contain a non-empty name.',
        );
      }
      return name;
    }).toList();
  }

  static Map<String, int> _readStats(Object? value) {
    if (value == null) return const {};
    if (value is! List) {
      throw const FormatException('Pokémon field "stats" must be a list.');
    }

    final Map<String, int> stats = {};
    for (final (int index, Object? item) in value.indexed) {
      if (item is! Map) {
        throw FormatException('Pokémon stats item $index must be an object.');
      }
      final Object? baseStat = item['base_stat'];
      final Object? rawStat = item['stat'];
      if (baseStat is! int || baseStat < 0 || rawStat is! Map) {
        throw FormatException('Pokémon stats item $index is incomplete.');
      }
      final Object? name = rawStat['name'];
      if (name is! String || name.trim().isEmpty) {
        throw FormatException(
          'Pokémon stats item $index must contain a non-empty stat name.',
        );
      }
      stats[name] = baseStat;
    }
    return stats;
  }

  static String? _readImageUrl(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const FormatException('Pokémon field "sprites" must be an object.');
    }

    final Object? other = value['other'];
    if (other != null && other is! Map) {
      throw const FormatException(
        'Pokémon sprite field "other" must be an object.',
      );
    }
    final Object? artwork = other is Map ? other['official-artwork'] : null;
    if (artwork != null && artwork is! Map) {
      throw const FormatException(
        'Pokémon official artwork field must be an object.',
      );
    }

    final String? artworkUrl = _optionalImageString(
      artwork is Map ? artwork['front_default'] : null,
    );
    if (artworkUrl != null) return artworkUrl;
    return _optionalImageString(value['front_default']);
  }

  static String? _optionalImageString(Object? value) {
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException(
        'Pokémon image URL must be a non-empty string.',
      );
    }
    return value;
  }
}
