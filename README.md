# UniPOS - Universal Point of Sale System

A comprehensive Flutter-based Point of Sale application supporting both **Retail** and **Restaurant** business types.

## Overview

UniPOS is a dual-mode POS system where users select their business type (Retail or Restaurant) during initial setup. Once selected, the business type is locked and cannot be changed. Each mode provides specialized features tailored to its specific industry needs.

### Retail Mode
- Product catalog management with WooCommerce-style attributes
- Multi-tab billing system
- Purchase order and GRN tracking
- Supplier and customer management
- GST/Tax calculation engine
- Credit payment system
- Comprehensive reporting

### Restaurant Mode
- Table management system
- Menu customization (choices, extras, variants)
- KOT (Kitchen Order Ticket) system
- Order types (dine-in, takeaway, delivery)
- Ingredient-based inventory tracking
- Local server for online orders
- Staff management

## Architecture

This application uses **two different architectural patterns** - one for retail and one for restaurant:

- **Retail:** Repository Pattern + MobX State Management (layered architecture)
- **Restaurant:** Direct Access Pattern (simplified architecture)

For detailed architectural documentation, see **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## Technology Stack

- **Framework:** Flutter
- **Database:** Hive (Local NoSQL)
- **State Management:** MobX (Retail), StatefulWidget (Restaurant)
- **Dependency Injection:** GetIt (Retail only)
- **Language:** Dart

## Project Structure

```
lib/
├── core/           # Shared infrastructure (config, DI, Hive init)
├── data/           # Data layer (models, repositories)
├── domain/         # Business logic (services, stores)
├── presentation/   # UI layer (screens, widgets)
├── util/           # Utilities (currency, image picker)
└── server/         # Local server (restaurant online orders)
```

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Dart SDK
- Android Studio / VS Code
- Android SDK or Xcode (for mobile deployment)

### Installation

1. Clone the repository
   ```bash
   git clone <repository-url>
   cd UniPOSs
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Run build runner (for Hive and MobX code generation)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. Run the app
   ```bash
   flutter run
   ```

### First Launch

On first launch, you'll be guided through a setup wizard:
1. Select business type (Retail or Restaurant)
2. Enter business details
3. Configure payment methods
4. Set up tax settings (if applicable)
5. Complete setup

**Note:** Business type selection is permanent and cannot be changed after setup.

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Comprehensive architectural documentation
- **[TAX_SYSTEM_COMPLETE_GUIDE.md](TAX_SYSTEM_COMPLETE_GUIDE.md)** - Tax configuration guide
- **[ORDER_PROCESSING_GUIDE.md](ORDER_PROCESSING_GUIDE.md)** - Order processing documentation
- **[SHARED_FUNCTIONALITY_ANALYSIS.md](SHARED_FUNCTIONALITY_ANALYSIS.md)** - Shared code analysis

## Development

### For Retail Features
Follow the layered architecture:
1. Create/update model in `data/models/retail/`
2. Create/update repository in `data/repositories/retail/`
3. Create/update store in `domain/store/retail/`
4. Register dependencies in `core/di/service_locator.dart`
5. Use in UI with MobX observers

### For Restaurant Features
Use the direct access pattern:
1. Create/update model in `data/models/restaurant/db/`
2. Create/update helper class in `data/models/restaurant/db/database/`
3. Use directly in UI with StatefulWidget

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed guidelines.

## Features

### Common Features (Both Modes)
- Customer management with loyalty points
- Credit/tab system
- Multiple payment methods
- Backup and restore functionality
- Print receipt support
- Business details configuration
- Staff management

### Retail-Specific
- Product variants with attributes
- Barcode scanning
- Purchase order management
- Supplier tracking
- GRN (Goods Received Notes)
- Stock alert system
- Multi-tab billing
- WooCommerce-style product attributes

### Restaurant-Specific
- Table layout and management
- Kitchen order tickets (KOT)
- Menu item customization
- Order type tracking
- Ingredient inventory
- Online ordering via local server
- Test bill generation

## Building for Production

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Windows
```bash
flutter build windows --release
```

## Contributing

1. Understand the architectural patterns (see ARCHITECTURE.md)
2. Follow the existing pattern for your feature's domain (retail/restaurant)
3. Test in the correct business mode
4. Update documentation if needed
5. Submit PR with clear description

## License

[Add your license information here]

## Support

For issues, questions, or contributions, please [open an issue](link-to-issues) on GitHub.

---

**Note:** This is a production POS application with two distinct architectural patterns. Please read [ARCHITECTURE.md](ARCHITECTURE.md) before contributing.
