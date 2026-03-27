# QuranReader

QuranReader is a native Flutter Android app for reading the Quran, tracking reading progress, and optionally opening Gemini-powered word and ayah insights.

It was built as a native replacement for the earlier `QuranTracker` WebView app. The app renders the bundled Quran text directly in Flutter, preserves Quran annotation signs with the bundled MeQuran font, lets you save progress by ayah range, and keeps your reading settings, progress, and saved AI insight responses locally on the device.

## Download

- Latest Android release APK: [app-release.apk](https://github.com/ariful19/QuranReader/releases/latest/download/app-release.apk)

## Features

- Native Flutter reader for the bundled Quran text
- Arabic reading view with Quran annotation signs rendered using the bundled MeQuran font
- Save progress by tapping an ayah and storing a range
- Smart range suggestions based on the next unread stretch
- Tap saved range chips to jump to the ending ayah
- Long-press a word in the continuous reader to open Gemini-powered Bengali word insights with linguistic notes
- Long-press an ayah marker to open Gemini-powered Bengali ayah insights with tafsir-style summary, themes, lessons, and linked sources when available
- Settings page to save or remove a Gemini API key and clear saved AI insights
- Cached AI responses for faster repeat lookups, with refresh actions in the insight dialogs
- Full-screen reading mode
- Reader settings for font size and background color
- Per-surah progress and total progress tracking
- Normal and chronological surah ordering
- Goal tracking and reset support

## Project Structure

- `lib/` Flutter application source
- `Resources/` Quran text and bundled Quran font assets, including the MeQuran annotation font
- `android/` Android host project
- `test/` widget and logic tests

## Notes

- The `QuranTracker/` folder in the local workspace was used as a reference during development and is intentionally not included in this public repository.
- Quran text attribution: Tanzil Project, Uthmani text.
- AI insights are optional and require a user-provided Gemini API key. The key is saved on-device, and insight responses are cached locally until cleared from Settings.
- Fresh AI insight requests require internet access.

## Getting Started

### Prerequisites

- Flutter SDK
- Android SDK
- A connected Android device or emulator
- A Gemini API key if you want to use the optional AI insight features

### Run

```bash
flutter pub get
flutter run
```

After the app opens, use the home screen Settings button to save a Gemini API key if you want word and ayah insights.

### Using AI Insights

- Long-press a word in the continuous reader to open a word insight dialog
- Long-press an ayah marker to open an ayah insight dialog
- Use the refresh button inside an insight dialog to bypass the saved response and request a fresh one

### Test

```bash
flutter analyze
flutter test
```

## GitHub CI/CD

GitHub Actions now:

- runs `flutter analyze` and `flutter test` on pull requests and pushes to `main`
- builds `app-release.apk` on manual workflow runs and version tags like `v1.0.0`
- publishes tagged APKs to GitHub Releases, which keeps the latest download link above up to date

## Android Release Signing

Release APKs must be signed with the same keystore locally and in CI. If you let Gradle fall back to machine-specific debug keys, a release built on GitHub Actions will not install over a local build that uses a different certificate.

1. Create an upload keystore, for example:

```bash
keytool -genkeypair -v -keystore android/upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

2. Copy `android/key.properties.example` to `android/key.properties` and fill in the real values:

```properties
storeFile=upload-keystore.jks
storePassword=your-keystore-password
keyAlias=upload
keyPassword=your-key-password
```

3. Add the same values as GitHub repository secrets so CI signs with the exact same certificate:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded contents of `android/upload-keystore.jks`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Example to produce the base64 value:

```bash
base64 android/upload-keystore.jks
```

If you already installed the app on a device from a locally built APK, keep using that same keystore in CI. Otherwise Android will reject the CI APK as an update because the signatures do not match. If you switch to a new keystore, uninstall the old app once before installing the newly signed release.

After that, both local `flutter build apk --release` and the GitHub Actions release workflow will produce installable APKs signed with the same key.
