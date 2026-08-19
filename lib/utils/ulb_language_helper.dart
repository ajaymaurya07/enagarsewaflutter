import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

import '../services/storage_service.dart';

/// Resolves whether Owner Name / Father Name / Address text should be
/// rendered in the ULB's configured legacy Krutidev font instead of the
/// app's default font.
///
/// The Krutidev .ttf lives at [krutidevAssetPath] and is registered under
/// `fonts:` in pubspec.yaml with the [krutidevFontFamily] family name, so it
/// is usable both by Flutter widgets (via `fontFamily`) and by generated PDFs
/// (via [pdfFontIfKrutidev], which loads the same .ttf through rootBundle).
class UlbLanguageHelper {
  UlbLanguageHelper._();

  static const String krutidevFontFamily = 'Krutidev010';
  static const String krutidevAssetPath = 'assets/font/Kruti Dev 010 Regular.ttf';

  static pw.Font? _cachedPdfFont;

  static Future<bool> isKrutidev() async {
    final language = await StorageService.getLanguageCache();
    return (language?.trim().toLowerCase() ?? '') == 'krutidev';
  }

  /// Loads (and caches) the Krutidev face for use inside `pdf` widgets.
  static Future<pw.Font> krutidevPdfFont() async {
    return _cachedPdfFont ??= pw.Font.ttf(await rootBundle.load(krutidevAssetPath));
  }

  /// Krutidev PDF face when [isKrutidev] is true, else `null` so callers can
  /// fall back to the document's default font.
  static Future<pw.Font?> pdfFontIfKrutidev(bool isKrutidev) async {
    return isKrutidev ? await krutidevPdfFont() : null;
  }
}
