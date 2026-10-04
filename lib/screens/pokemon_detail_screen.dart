import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pokedex_app/models/pokemon.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';
import 'package:pokedex_app/state/favorites_scope.dart';
import 'package:pokedex_app/state/favorites_store.dart';

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
  static const Color _ink = Color(0xFF20324D);
  static const Color _mutedInk = Color(0xFF64748B);
  static const double _maxBaseStat = 255;
  static const List<(String, String)> _statDefinitions = [
    ('hp', 'HP'),
    ('attack', 'Attack'),
    ('defense', 'Defense'),
    ('special-attack', 'Special Attack'),
    ('special-defense', 'Special Defense'),
    ('speed', 'Speed'),
  ];

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

  Widget _buildError(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: _ink),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not load Pokémon details.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _details = _api.fetchPokemonDetails(
                          widget.pokemon.id.toString(),
                        );
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Pokemon pokemon) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final FavoritesStore favorites = FavoritesScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double horizontalPadding = constraints.maxWidth > 760
            ? (constraints.maxWidth - 720) / 2
            : 16;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroCard(context, pokemon, favorites, colors),
              if (pokemon.height != null || pokemon.weight != null) ...[
                const SizedBox(height: 20),
                _buildSectionCard(
                  context,
                  title: 'Measurements',
                  child: LayoutBuilder(
                    builder: (context, measurementConstraints) {
                      final double width = measurementConstraints.maxWidth;
                      if (width >= 380) {
                        final double itemWidth = (width - 12) / 2;
                        return Row(
                          children: [
                            _buildMeasurement(
                              key: const ValueKey('measurement-height'),
                              width: itemWidth,
                              label: 'Height',
                              value: pokemon.height == null
                                  ? 'Unknown'
                                  : '${pokemon.height! / 10} m',
                              icon: Icons.height,
                              colors: colors,
                            ),
                            const SizedBox(width: 12),
                            _buildMeasurement(
                              key: const ValueKey('measurement-weight'),
                              width: itemWidth,
                              label: 'Weight',
                              value: pokemon.weight == null
                                  ? 'Unknown'
                                  : '${pokemon.weight! / 10} kg',
                              icon: Icons.monitor_weight_outlined,
                              colors: colors,
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildMeasurement(
                            key: const ValueKey('measurement-height'),
                            width: width,
                            label: 'Height',
                            value: pokemon.height == null
                                ? 'Unknown'
                                : '${pokemon.height! / 10} m',
                            icon: Icons.height,
                            colors: colors,
                          ),
                          const SizedBox(height: 12),
                          _buildMeasurement(
                            key: const ValueKey('measurement-weight'),
                            width: width,
                            label: 'Weight',
                            value: pokemon.weight == null
                                ? 'Unknown'
                                : '${pokemon.weight! / 10} kg',
                            icon: Icons.monitor_weight_outlined,
                            colors: colors,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              if (pokemon.abilities.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'Abilities',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: pokemon.abilities
                        .map(
                          (ability) => Chip(
                            avatar: const Icon(Icons.auto_awesome, size: 16),
                            label: Text(_title(ability)),
                            backgroundColor: colors.surfaceContainerHighest,
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (pokemon.stats.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'Base stats',
                  child: _buildStatsChart(pokemon, colors),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    Pokemon pokemon,
    FavoritesStore favorites,
    ColorScheme colors,
  ) {
    return Card(
      color: colors.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '#${pokemon.id.toString().padLeft(3, '0')}',
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: favorites.isFavorite(pokemon.id)
                      ? 'Remove favorite'
                      : 'Add favorite',
                  onPressed: () => favorites.toggleFavorite(pokemon.id),
                  icon: Icon(
                    favorites.isFavorite(pokemon.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 210,
              child: Image.network(
                pokemon.imageUrl ??
                    'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${pokemon.id}.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.catching_pokemon,
                  size: 120,
                  color: _mutedInk,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _title(pokemon.name),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: _ink,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            if (pokemon.types.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: pokemon.types
                    .map(
                      (type) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _title(type),
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE9EDF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(color: _ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurement({
    required Key key,
    required double width,
    required String label,
    required String value,
    required IconData icon,
    required ColorScheme colors,
  }) {
    return SizedBox(
      key: key,
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: _mutedInk)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsChart(Pokemon pokemon, ColorScheme colors) {
    final List<double> normalizedValues = _statDefinitions.map((definition) {
      final int value = pokemon.stats[definition.$1] ?? 0;
      return (value / _maxBaseStat).clamp(0.0, 1.0);
    }).toList();

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final double chartSize = math.min(constraints.maxWidth, 340);
            return Center(
              child: SizedBox.square(
                key: const ValueKey('pokemon-stats-radar-chart'),
                dimension: chartSize,
                child: CustomPaint(
                  painter: _PokemonStatsRadarPainter(
                    values: normalizedValues,
                    dataColor: colors.primary,
                    gridColor: const Color(0xFFD5DCE6),
                    axisColor: const Color(0xFF9AA8BC),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        const Text(
          'Axes clockwise from the top: HP, Attack, Defense, Special Attack, '
          'Special Defense, Speed. Scale: 0–255 base-stat points; missing '
          'stats are plotted as 0.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _mutedInk, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            for (final (String key, String label) in _statDefinitions)
              SizedBox(
                width: 130,
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      pokemon.stats[key]?.toString() ?? '—',
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: Text(_title(widget.pokemon.name)),
        backgroundColor: const Color(0xFFF8F8FA),
      ),
      body: FutureBuilder<Pokemon>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _buildError(context);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildContent(context, snapshot.data!);
        },
      ),
    );
  }
}

class _PokemonStatsRadarPainter extends CustomPainter {
  const _PokemonStatsRadarPainter({
    required this.values,
    required this.dataColor,
    required this.gridColor,
    required this.axisColor,
  });

  final List<double> values;
  final Color dataColor;
  final Color gridColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.max(
      0,
      math.min(size.width, size.height) / 2 - 14,
    );
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Paint axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    List<Offset> pointsAt(double scale) => List<Offset>.generate(6, (index) {
      final double angle = -math.pi / 2 + index * math.pi / 3;
      return Offset(
        center.dx + math.cos(angle) * radius * scale,
        center.dy + math.sin(angle) * radius * scale,
      );
    });

    for (int ring = 1; ring <= 5; ring++) {
      final List<Offset> points = pointsAt(ring / 5);
      final Path path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final Offset point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (final Offset point in pointsAt(1)) {
      canvas.drawLine(center, point, axisPaint);
    }

    final List<Offset> dataPoints = List<Offset>.generate(6, (index) {
      final double angle = -math.pi / 2 + index * math.pi / 3;
      final double value = index < values.length
          ? values[index].clamp(0.0, 1.0)
          : 0;
      return Offset(
        center.dx + math.cos(angle) * radius * value,
        center.dy + math.sin(angle) * radius * value,
      );
    });
    final Path dataPath = Path()
      ..moveTo(dataPoints.first.dx, dataPoints.first.dy);
    for (final Offset point in dataPoints.skip(1)) {
      dataPath.lineTo(point.dx, point.dy);
    }
    dataPath.close();

    canvas.drawPath(
      dataPath,
      Paint()
        ..color = dataColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = dataColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (final Offset point in dataPoints) {
      canvas.drawCircle(point, 3.5, Paint()..color = dataColor);
    }
  }

  @override
  bool shouldRepaint(covariant _PokemonStatsRadarPainter oldDelegate) {
    if (oldDelegate.dataColor != dataColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.values.length != values.length) {
      return true;
    }
    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
