# enagarsewa

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

## Runtime Configuration

The app requires the API base URL to be passed at build or run time so the environment is not hardcoded in source.

Example:

```bash
flutter run --dart-define=BASE_URL=https://iamsup.in/ulb_property_tax/
flutter build apk --dart-define=BASE_URL=https://iamsup.in/ulb_property_tax/
```

You can supply a staging or production URL through the same `BASE_URL` define.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
