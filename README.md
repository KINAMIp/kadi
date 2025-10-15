# Tucheze Kadi

Tucheze Kadi is a modern, multiplayer spin on classic Kenyan card play. This repository houses the Flutter client, core rule engine, and supporting assets for the experience.

## Project Structure
- **lib/** – Flutter source code, including the rule engine (`lib/engine`), UI widgets, and services.
- **assets/** – Card art and shared media.
- **docs/** – Living design references for gameplay and presentation.

## Key Documentation
- [KADI Core Game Logic](docs/game_logic.md) – authoritative breakdown of every card, penalty, and win condition.
- [Visual & Interactive Blueprint](docs/environment_blueprint.md) – splash, lobby, and in-game presentation goals.

## Getting Started
1. Install the Flutter SDK (3.16 or later recommended).
2. Run `flutter pub get` to fetch dependencies.
3. Launch the application with `flutter run` targeting your preferred platform.

### Useful Commands
- `flutter test` – execute the automated test suite.
- `flutter analyze` – static analysis for Dart code.
- `flutter run -d chrome` – launch the web build in Chrome.

## Contributing
Contributions are welcome! Please open an issue to discuss major changes and ensure the rule engine behaviour remains consistent with the [game logic reference](docs/game_logic.md).
