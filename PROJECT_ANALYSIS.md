# UniPOS Project Analysis

## 1. Project Overview
**UniPOS** is a Universal POS (Point of Sale) application built with Flutter, designed to run on multiple platforms (Windows, Android, iOS, Linux, macOS, Web).

### Technology Stack
- **Framework**: Flutter (SDK ^3.8.1)
- **Language**: Dart
- **State Management**: [MobX](https://pub.dev/packages/mobx) (`mobx`, `flutter_mobx`)
- **Local Database**: [Hive](https://pub.dev/packages/hive) (`hive`, `hive_flutter`)
- **Dependency Injection**: [GetIt](https://pub.dev/packages/get_it)
- **Routing**: Flutter Named Routes

## 2. Architecture
The project follows a **MVVM (Model-View-ViewModel)** pattern with elements of **Clean Architecture**.

- **View (UI)**: Located in `lib/screen` and `lib/presentation`. These are Flutter widgets that observe Stores.
- **ViewModel (State)**: Located in `lib/stores`. These are MobX stores that hold state (`@observable`), actions (`@action`), and computed values (`@computed`).
- **Model (Data)**: Located in `lib/models` and `lib/data/models`. These are PODO (Plain Old Dart Objects) annotated for Hive.
- **Repository**: Located in `lib/data/repositories`. Abstracts the data source (Hive) from the rest of the app.

## 3. Directory Structure (`lib/`)

| Directory | Description |
|---|---|
| `Boxes/` | Contains Hive-related logic or Box definitions (e.g., `hive_store_details.dart`). |
| `core/` | Core utilities, configuration, and DI setup (`di/service_locator.dart`). |
| `data/` | Data layer containing `models/` and `repositories/`. |
| `domain/` | Domain layer (currently likely contains interfaces/services). |
| `models/` | Data models and their Hive TypeAdapters (e.g., `StoreDetails`, `TaxDetails`). |
| `presentation/` | UI related components (likely a newer structure alongside `screen`). |
| `screen/` | Main application screens (Views) (e.g., `loginScreen.dart`, `setupWizardScreen.dart`). |
| `stores/` | MobX Stores (ViewModels) (e.g., `setup_wizard_store.dart`). |
| `util/` | Utility classes for colors, images, and responsiveness. |
| `main.dart` | Entry point, Hive initialization, DI setup, and Routing configuration. |

## 4. Key Mechanisms

### State Management (MobX)
- **Stores**: Classes ending in `_store.dart` (e.g., `SetupWizardStore`).
- **Code Generation**: Uses `build_runner` to generate `*.g.dart` files for MobX.
- **Usage**:
    ```dart
    // In Store
    @observable
    String name = '';

    @action
    void setName(String value) => name = value;

    // In View
    // Observer(builder: (_) => Text(store.name));
    ```

### Data Persistence (Hive)
- **Initialization**: Done in `main.dart` (`Hive.initFlutter()`).
- **Adapters**: Registered in `main.dart` with specific IDs (e.g., 0, 2, 10, 102).
- **Boxes**: Opened at startup.
- **Usage**: Repositories access `Hive.box<Type>('boxName')` to CRUD data.

### Dependency Injection (GetIt)
- **Setup**: `lib/core/di/service_locator.dart`.
- **Registration**:
    - Repositories are typically registered as **Lazy Singletons**.
    - Stores are registered as **Factories** or **Singletons** depending on lifecycle needs.
- **Access**: `final store = getIt<SetupWizardStore>();`

## 5. Observations & Recommendations
- **Model Locations**: Models are split between `lib/models` and `lib/data/models`. It is recommended to consolidate them into `lib/data/models` or a dedicated `lib/domain/entities` folder for consistency.
- **Screen Directory**: `lib/screen` (singular) vs `lib/presentation` (standard clean arch). The project seems to be transitioning or mixing structures. Standardizing on `presentation/screens` or `presentation/pages` is recommended.
- **File Naming**: Some files use camelCase (e.g., `loginScreen.dart`) while Dart convention is snake_case (e.g., `login_screen.dart`). New files should follow snake_case.

## 6. How to Run
1.  **Get Dependencies**: `flutter pub get`
2.  **Generate Code** (for MobX & Hive): `dart run build_runner build --delete-conflicting-outputs`
3.  **Run App**: `flutter run`
