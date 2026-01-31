# LS Tech Inventory App

A robust, offline-capable inventory management system built with Flutter. This application is designed to streamline stock tracking, specifically tailored for scanning and managing reel-based inventory updates via QR codes.

## 🚀 Features

### 1. **User Interface (UI/UX)**
-   **Modern Design**: Clean, card-based UI with soft shadows and rounded corners (Radius 16), providing a premium look and feel.
-   **Consistent Aesthetic**: Uniform design language across all screens (Home, Register, Inward, Outward, Inventory).
-   **Custom Branding**: Integrated custom "LS Logo" for the app icon and splash screen.

### 2. **Core Modules**
-   **Home Dashboard**: Quick navigation to all major functions (Register, Inward, Outward, Inventory).
-   **Register Product**:
    -   Create new product entries (Name, Packing Quantity, etc.).
    -   Generate and print initial QR codes for new stock.
-   **Inward Processing**:
    -   Add stock to existing products easily.
    -   Automatically generates "Inward Labels" (85mm x 24mm) with QR codes for new reels.
-   **Outward Processing**:
    -   Scan Outward: Use the built-in camera with a **custom overlay** to scan reel QR codes.
    -   Batch Scanning: Scan multiple items and review them before submission.
    -   Invoice Integration: Link outward stock to specific Invoice and PO numbers.
    -   **PDF Generation**: Auto-generates an "Outward Label" PDF (85mm x 32mm) documenting the shipment.
-   **Inventory Management**:
    -   Real-time view of Total Stock, Available Stock, and Outwarded Stock.
    -   Detailed history view for every product (Inward & Outward logs).
    -   Individual Reel status tracking.

### 3. **Technical Highlights**
-   **Offline-First**: Uses `sqflite` for robust local database storage. No internet connection required for core operations.
-   **QR Code Integration**:
    -   **Scanning**: fast scanning using `mobile_scanner` with a transparent overlay UI.
    -   **Generation**: generates high-quality QR codes for printing using `pdf` and `printing` packages.
-   **PDF Reports**: Custom PDF label generation with precise dimensions for thermal printers.

## 🛠️ Tech Stack

-   **Framework**: Flutter (Dart)
-   **Database**: SQLite (`sqflite`)
-   **State Management**: `setState` (Native) & Service-based architecture
-   **Packages**:
    -   `mobile_scanner`: QR Code scanning
    -   `pdf` & `printing`: PDF creation and preview/sharing
    -   `google_fonts`: Typography (Inter font)
    -   `path_provider`: File system access
    -   `intl`: Date formatting
    -   `uuid`: Unique ID generation

## 📱 Screenshots

| Home Screen | Outward Scan | Inventory |
|:-----------:|:------------:|:---------:|
| *(Add Screenshot)* | *(Add Screenshot)* | *(Add Screenshot)* |

## 🏁 Getting Started

### Prerequisites
-   [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
-   Android Studio (for Android emulator/device testing).

### Installation

1.  **Clone the repository** (if applicable) or copy source files.
    ```bash
    git clone <repository-url>
    ```
2.  **Navigate to the project directory**:
    ```bash
    cd LS_TECH_APP
    ```
3.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
4.  **Run the App**:
    ```bash
    flutter run
    ```

## 📄 License

This project is proprietary software developed for LS Tech.

## ✍️ Author

**Rohit Pani**
- Email: [rohitpani1624@gmail.com](mailto:rohitpani1624@gmail.com)
