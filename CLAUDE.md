# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LS Tech Inventory App is an offline-first inventory management system built with Flutter for LS Technology. It manages reel-based inventory using QR code scanning for product registration, inward stock operations, and outward shipments.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Build Android APK
flutter build apk

# Build Android App Bundle
flutter build appbundle

# Run tests
flutter test

# Analyze code
flutter analyze

# Generate app icons (after modifying assets/logo.png)
flutter pub run flutter_launcher_icons:main
```

## Architecture

**Service-Based Architecture with Singleton Pattern**

- `lib/models/` - Data models with `toMap()` and `fromMap()` serialization
  - `product.dart` - Product entity
  - `reel.dart` - Reel entity with QR code data
  - `transaction_record.dart` - Inward/Outward transaction records
- `lib/services/database_service.dart` - Singleton database service handling all SQLite operations
- `lib/screens/` - Stateful widgets for each screen
- `lib/main.dart` - App entry point with named route definitions

**State Management**: Native `setState` with service-based data access

**Navigation**: Named routes defined in `main.dart` (`/register`, `/inward`, `/outward`, `/inventory`)

## Database Schema (SQLite)

Four tables in `inventory_app.db`:
- **products** - Product entries with stock counts and reel tracking
- **reels** - Individual reels with QR codes, status ('available'/'outward')
- **inward_records** - Stock addition history
- **outward_records** - Shipment history with invoice numbers

## QR Code Format

Reels use format: `product_id|date|quantity|reel_number`

## PDF Label Dimensions

- Register/Inward labels: 85mm x 24mm
- Outward labels: 85mm x 32mm

## Key Dependencies

- `sqflite` - Local SQLite database
- `mobile_scanner` - QR code scanning
- `pdf` + `printing` - PDF generation and printing
- `google_fonts` - Inter font family
