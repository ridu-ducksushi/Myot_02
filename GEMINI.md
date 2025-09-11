# PetCare Mobile App

## Project Overview

This is a personal pet-care tracker for individual pet owners built with Flutter and Supabase.

**Key Technologies:**

*   **Frontend:** Flutter
*   **Backend:** Supabase (Auth, Database, Storage)
*   **Local DB:** Isar (offline-first)
*   **State Management:** Riverpod
*   **Push Notifications:** Firebase Cloud Messaging
*   **Analytics:** Firebase Analytics & Crashlytics
*   **Localization:** easy_localization (Korean, English, Japanese)

**Architecture:**

The application follows a standard Flutter project structure. The core business logic is separated from the UI, and the data layer is managed by repositories that interact with both the local Isar database and the remote Supabase backend.

## Building and Running

**1. Setup:**

*   Copy `env.template` to `.env` and fill in your Supabase credentials.

**2. Install Dependencies:**

```bash
flutter pub get
```

**3. Generate Code:**

```bash
dart run build_runner build
```

**4. Run the App:**

```bash
flutter run --dart-define-from-file=.env
```

**5. Testing:**

To run the tests, use the following command:

```bash
flutter test
```

## Development Conventions

*   **State Management:** The project uses [Riverpod](https://riverpod.dev/) for state management.
*   **Code Generation:** The project uses `freezed` for immutable data classes and `json_serializable` for JSON serialization.
*   **Linting:** The project uses `very_good_analysis` for linting.
*   **Localization:** The project uses the `easy_localization` package for localization. Translation files are located in `assets/i18n`.
