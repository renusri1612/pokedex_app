import 'package:pokedex_app/screens/pokemon_list_screen.dart';
import 'package:pokedex_app/screens/favorites_screen.dart';
import 'package:flutter/material.dart';
import 'package:pokedex_app/state/favorites_scope.dart';
import 'package:pokedex_app/state/favorites_store.dart';
import 'package:pokedex_app/services/pokemon_api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PokedexApp());
}

class PokedexApp extends StatefulWidget {
  const PokedexApp({super.key, this.favoritesStore, this.apiServiceFactory});

  final FavoritesStore? favoritesStore;
  final PokemonApiService Function()? apiServiceFactory;

  @override
  State<PokedexApp> createState() => _PokedexAppState();
}

class _PokedexAppState extends State<PokedexApp> {
  late final FavoritesStore _favoritesStore;
  late Future<void> _favoritesLoading;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();

    _favoritesStore = widget.favoritesStore ?? FavoritesStore();
    _favoritesLoading = _favoritesStore.loadFavorites();
  }

  @override
  void dispose() {
    if (widget.favoritesStore == null) {
      _favoritesStore.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FavoritesScope(
      store: _favoritesStore,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Pokédex',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935)),
          scaffoldBackgroundColor: const Color(0xFFF8F8FA),
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            backgroundColor: Color(0xFFF8F8FA),
          ),
        ),
        home: FutureBuilder<void>(
          future: _favoritesLoading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load your saved favorites.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _favoritesLoading = _favoritesStore
                                  .loadFavorites();
                            });
                          },
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final FavoritesStore favoritesStore = FavoritesScope.of(context);
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  _selectedTab == 0 ? 'Pokédex' : 'Favorites',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              body: Column(
                children: [
                  if (favoritesStore.persistenceError != null)
                    MaterialBanner(
                      content: const Text(
                        'Favorites changed but could not be saved. Retry to keep them after restart.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: favoritesStore.retryPersistence,
                          child: const Text('Retry save'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedTab,
                      children: [
                        PokemonListScreen(
                          apiServiceFactory: widget.apiServiceFactory,
                        ),
                        FavoritesScreen(
                          apiServiceFactory: widget.apiServiceFactory,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedTab,
                onDestinationSelected: (index) =>
                    setState(() => _selectedTab = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.catching_pokemon),
                    label: 'Pokédex',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.favorite),
                    label: 'Favorites',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class PokedexHomePlaceholder extends StatelessWidget {
  const PokedexHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pokédex',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.catching_pokemon, size: 80, color: Color(0xFFE53935)),
            SizedBox(height: 16),
            Text(
              'Your Pokédex adventure starts here!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('Next up: loading Pokémon from PokéAPI.'),
          ],
        ),
      ),
    );
  }
}
