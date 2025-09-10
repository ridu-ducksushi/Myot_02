# PetCare Mobile App

A personal pet-care tracker for individual pet owners built with Flutter and Supabase.

## Features

- Multi-pet management (dogs, cats, etc.)
- Health records tracking (meals, medications, vet visits)
- Lab results storage
- Reminders for care activities
- Offline-first with cloud sync
- Multi-language support (Korean, English, Japanese)

## Setup

1. Copy `env.template` to `.env` and fill in your Supabase credentials
2. Run `flutter pub get`
3. Run `dart run build_runner build` to generate code
4. Run `flutter run --dart-define-from-file=.env`

## Tech Stack

- **Frontend**: Flutter with Riverpod state management
- **Backend**: Supabase (Auth, Database, Storage)
- **Local DB**: Isar (offline-first)
- **Push Notifications**: Firebase Cloud Messaging
- **Analytics**: Firebase Analytics & Crashlytics

## License

MIT License - see LICENSE file for details.