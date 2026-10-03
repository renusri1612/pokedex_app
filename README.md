# Flutter Pokédex

A small Flutter app for browsing Pokémon from [PokéAPI](https://pokeapi.co/), viewing their details, and saving favorites on the device. The project uses Flutter's built-in widget/state tools and keeps network, parsing, and favorite persistence code in separate files.

## Features

- Browse Pokémon in pages of 20 with names and sprite images.
- Search case-insensitively by part of a Pokémon name. Search covers records loaded so far; use **Load More Pokémon** to include more records.
- Open a Pokémon from the list or Favorites to view its ID, artwork, types, measurements, abilities, and available base stats.
- Add or remove favorites from the list, detail, and Favorites screens. Changes appear through one shared favorites store.
- Save favorite IDs with `shared_preferences` and restore them on startup. A visible retry action appears if saving fails.
- Show loading, empty, and retryable error states for list, detail, and Favorites requests.

## Screens and navigation

The main screen has bottom navigation for **Pokédex** and **Favorites**. Selecting a list or Favorites item pushes the same detail screen. The list and Favorites screens remain in an `IndexedStack` while switching tabs, so their widget state is retained.

## Technologies

| Technology/package | Purpose |
| --- | --- |
| Flutter and Dart | Cross-platform UI and application logic |
| `http` | Calls to PokéAPI; clients can be injected for tests |
| `shared_preferences` | Stores favorite Pokémon IDs locally |
| `flutter_test` | Unit and widget tests |
| `flutter_lints` | Dart/Flutter static-analysis rules |
| `cupertino_icons` | Cupertino icon package included in project dependencies |

The package versions and SDK constraint are declared in [`pubspec.yaml`](pubspec.yaml); resolved versions are recorded in `pubspec.lock`.

## Prerequisites

- Windows 10 or 11.
- Flutter SDK installed and available on `PATH` (Dart is included with Flutter).
- Google Chrome installed to run the web app.
- Visual Studio Code with the Flutter and Dart extensions is recommended, but optional.
- For Android: Android Studio, Android SDK and platform tools, an emulator or USB-connected device, and an accepted Android SDK license.
- Internet access for Pokémon data and remote images.

Use PowerShell from the project directory:

```powershell
Set-Location C:\srcfolder\pokedex_app
flutter doctor
flutter --version
flutter pub get
```

`flutter doctor` reports whether Flutter can find the relevant platform tools. For Android setup, install the SDK/emulator through Android Studio and then run `flutter doctor --android-licenses` if requested.

## Run the app

Run in Chrome:

```powershell
flutter devices
flutter run -d chrome
```

Run on Android after starting an emulator or connecting an authorized device:

```powershell
flutter devices
flutter run -d <device-id>
```

Replace `<device-id>` with an ID printed by `flutter devices`. Android configuration includes the Internet permission in `android/app/src/main/AndroidManifest.xml`. Android execution depends on a working local Android SDK/device setup; this README does not claim a particular device was tested.

## Project structure

```text
lib/
  main.dart                         App startup, tab navigation, app-wide states
  models/pokemon.dart               Pokémon model and defensive JSON parsing
  services/pokemon_api_service.dart HTTP requests, response checks, timeouts
  screens/
    pokemon_list_screen.dart        List, local search, pagination
    pokemon_detail_screen.dart      Detail loading and favorite action
    favorites_screen.dart           Shared favorites list and detail loading
  state/
    favorites_store.dart            Favorite IDs and local persistence
    favorites_scope.dart             Makes the shared store available to widgets
test/                               Deterministic unit and widget tests
android/                            Android project and Internet permission
```

`main()` calls `runApp()` with `PokedexApp`. The screen widgets call `PokemonApiService`, which sends HTTP requests and turns JSON into `Pokemon` objects. `FavoritesStore` is the single in-memory source of favorite IDs and writes IDs to `shared_preferences`; `FavoritesScope` exposes that store to screens.

## PokéAPI usage

The app requests paginated list data from `https://pokeapi.co/api/v2/pokemon?limit=...&offset=...` and detail data from `https://pokeapi.co/api/v2/pokemon/{id}`. The service validates response status and shape, reports malformed JSON clearly, and gives each request a 15-second timeout. Detail JSON supplies the fields used for artwork, types, height, weight, abilities, and base stats. If optional fields are absent, the detail screen omits those sections or falls back to the sprite URL.

Tests inject `http.testing.MockClient` responses, so the automated suite does not need live PokéAPI access.

## Development and tests

From the project directory:

```powershell
dart format .
flutter analyze
flutter test
flutter test --concurrency=1
```

Formatting rewrites Dart source into a consistent style. `flutter analyze` checks code without running the app. `flutter test` runs unit and widget tests; use `--concurrency=1` to run test files one at a time, which can simplify debugging. These commands are separate from launching the app.

## Known limitations

- Search is local and includes only Pokémon pages already loaded; it is not a server-wide search.
- Pagination is manual, through a load-more control.
- Pokémon details and images are fetched from remote services; Pokémon details are not cached for offline use. Favorites persist as IDs, but displaying Favorites still needs detail requests.
- Favorite changes update the UI immediately. If local saving fails, the app displays an error and retry action. If the app is closed before a successful retry, the latest changes may not be on disk.
- Request timeouts stop the app from waiting, but `Future.timeout` does not cancel the underlying `http.Client` request.
- The app depends on PokéAPI and remote image availability; no deployment or offline mode is included.
