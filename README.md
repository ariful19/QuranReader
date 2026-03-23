# QuranReader

QuranReader is a native Flutter Android app for reading the Quran and tracking reading progress.

It was built as a native replacement for the earlier `QuranTracker` WebView app. The app renders the bundled Quran text directly in Flutter, lets you save progress by ayah range, and keeps your reading settings and progress locally on the device.

## Features

- Native Flutter reader for the bundled Quran text
- Clean Arabic reading view with Quran annotation signs hidden on-screen
- Save progress by tapping an ayah and storing a range
- Smart range suggestions based on the next unread stretch
- Tap saved range chips to jump to the ending ayah
- Full-screen reading mode
- Reader settings for font size and background color
- Per-surah progress and total progress tracking
- Normal and chronological surah ordering
- Goal tracking and reset support

## Project Structure

- `lib/` Flutter application source
- `Resources/` Quran text and Quran font assets used by the app
- `android/` Android host project
- `test/` widget and logic tests

## Notes

- The `QuranTracker/` folder in the local workspace was used as a reference during development and is intentionally not included in this public repository.
- Quran text attribution: Tanzil Project, Uthmani text.

## Getting Started

### Prerequisites

- Flutter SDK
- Android SDK
- A connected Android device or emulator

### Run

```bash
flutter pub get
flutter run
```

### Test

```bash
flutter analyze
flutter test
```
