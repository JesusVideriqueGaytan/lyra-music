/// Catálogo incluido en la compilación, revisado mediante PR.
/// Nunca trata un manifiesto descargado como código ejecutable.
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lyra_music/features/extensions/domain/extension_manifest.dart';

List<ExtensionManifest> parseApprovedCatalog(String raw) {
  final data = jsonDecode(raw);
  if (data is! Map<String, dynamic> ||
      data['schemaVersion'] != 1 ||
      data['extensions'] is! List) {
    throw const FormatException('Formato de catálogo incompatible');
  }
  final items = <ExtensionManifest>[];
  final seen = <String>{};
  for (final rawEntry in data['extensions'] as List) {
    if (rawEntry is! Map<String, dynamic>) {
      throw const FormatException('Entrada de catálogo inválida');
    }
    final manifest = ExtensionManifest.fromJson(rawEntry);
    if (!seen.add(manifest.id)) {
      throw FormatException('ID duplicado: ${manifest.id}');
    }
    items.add(manifest);
  }
  return List.unmodifiable(items);
}

final approvedExtensionCatalogProvider =
    FutureProvider<List<ExtensionManifest>>((ref) async {
      final raw = await rootBundle.loadString('assets/extensions/catalog.json');
      return parseApprovedCatalog(raw);
    });
