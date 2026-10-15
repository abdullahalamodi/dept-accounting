import 'dart:convert';

import 'package:flutter/services.dart';

Future<void> loadAppFonts() async {
  final families = (jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<Object?>).cast<Map<String, Object?>>();
  for (final family in families) {
    final loader = FontLoader(family['family']! as String);
    final fonts = (family['fonts']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final assets = fonts.map((font) => font['asset']! as String).toSet();
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
