class Pokemon {
  final int id;
  final String name;
  final String url;

  const Pokemon({required this.id, required this.name, required this.url});

  factory Pokemon.fromApiResult(Map<String, dynamic> json) {
    final String name = json['name'] as String;
    final String url = json['url'] as String;

    final Uri uri = Uri.parse(url);
    final List<String> segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    final int id = int.parse(segments[segments.length - 1]);

    return Pokemon(id: id, name: name, url: url);
  }
}
