/// Manifiestos de catálogo declarativos: no descargan ni ejecutan código.
library;

class ExtensionManifest {
  const ExtensionManifest({
    required this.id,
    required this.name,
    required this.summary,
    required this.author,
    required this.version,
    required this.category,
  });

  final String id;
  final String name;
  final String summary;
  final String author;
  final String version;
  final String category;

  static final RegExp _idPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$');
  static final RegExp _versionPattern = RegExp(r'^\d+\.\d+\.\d+$');

  factory ExtensionManifest.fromJson(Map<String, dynamic> json) {
    String field(String key, int maxLength) {
      final value = json[key];
      if (value is! String ||
          value.trim().isEmpty ||
          value.length > maxLength) {
        throw FormatException('Campo inválido: $key');
      }
      return value.trim();
    }

    const allowedKeys = {
      'id',
      'name',
      'summary',
      'author',
      'version',
      'category',
    };
    if (json.keys.toSet().difference(allowedKeys).isNotEmpty) {
      throw const FormatException('Campos no autorizados en el manifiesto');
    }
    final id = field('id', 64);
    final version = field('version', 32);
    if (!_idPattern.hasMatch(id) || !_versionPattern.hasMatch(version)) {
      throw const FormatException('ID o versión inválidos');
    }
    final category = field('category', 32);
    if (!const {
      'appearance',
      'metadata',
      'integration',
      'tools',
    }.contains(category)) {
      throw const FormatException('Categoría no autorizada');
    }
    return ExtensionManifest(
      id: id,
      name: field('name', 80),
      summary: field('summary', 280),
      author: field('author', 80),
      version: version,
      category: category,
    );
  }
}
