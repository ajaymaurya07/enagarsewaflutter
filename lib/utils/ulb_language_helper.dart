import '../services/storage_service.dart';

/// Resolves whether Owner Name / Father Name / Address text should be
/// rendered in the ULB's configured legacy Krutidev font instead of the
/// app's default font.
///
/// NOTE: The actual Krutidev .ttf must be added under `assets/fonts/` and
/// registered under `fonts:` in pubspec.yaml with this family name before
/// this has any visual effect. Until then, screens using this helper fall
/// back to the default font.
class UlbLanguageHelper {
  UlbLanguageHelper._();

  static const String krutidevFontFamily = 'Krutidev010';

  static Future<bool> isKrutidev() async {
    final language = await StorageService.getLanguageCache();
    return (language?.trim().toLowerCase() ?? '') == 'krutidev';
  }
}
