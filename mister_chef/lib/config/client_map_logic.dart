import 'package:flutter/material.dart';

/// Valor del selector de vendedor que representa "Todos".
const String sellerFilterAll = '__all__';

/// Valor del selector de vendedor que representa "Sin asignar".
const String sellerFilterUnassigned = '__unassigned__';

/// Paleta estable para los marcadores del mapa del administrador.
///
/// El orden de [colors] y [hues] es el mismo para que un vendedor conserve
/// siempre el mismo color, sin importar qué domiciliarios estén conectados
/// ni en qué orden lleguen los datos de la API.
class ClientMapPalette {
  ClientMapPalette._();

  /// Color de cada vendedor, en el mismo orden que [hues].
  static const List<Color> colors = <Color>[
    Color(0xFFF44336), // rojo
    Color(0xFF2196F3), // azul
    Color(0xFF4CAF50), // verde
    Color(0xFF9C27B0), // violeta
    Color(0xFFFF9800), // naranja
    Color(0xFF00BCD4), // cian
    Color(0xFFFFC107), // amarillo
    Color(0xFFE91E63), // rosado
  ];

  /// Hue de `BitmapDescriptor.defaultMarkerWithHue` para cada color.
  static const List<double> hues = <double>[
    0.0, // hueRed
    240.0, // hueBlue
    120.0, // hueGreen
    270.0, // hueViolet
    30.0, // hueOrange
    180.0, // hueCyan
    60.0, // hueYellow
    330.0, // hueRose
  ];

  /// Color neutro para clientes sin vendedor asignado.
  static const Color unassigned = Color(0xFF9E9E9E);

  /// Número de colores disponibles.
  static int get length => colors.length;
}

/// Normaliza un documento de empleado a texto no vacío.
///
/// La API puede devolver documentos como número o como string, por lo que
/// ambos casos se comparan siempre como texto.
String? normalizeDocument(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// Construye una lista ordenada y sin duplicados de documentos de vendedor.
///
/// El orden es lexicográfico sobre el documento ya normalizado. Al ser estable,
/// el índice de color de cada vendedor no cambia entre refrescos.
List<String> buildSortedSellerDocuments(Iterable<dynamic> documents) {
  final unique = <String>{};
  for (final item in documents) {
    final document = normalizeDocument(item);
    if (document != null) unique.add(document);
  }
  final sorted = unique.toList()..sort();
  return sorted;
}

/// Índice de color de [document] dentro de [sortedSellerDocuments].
///
/// Devuelve `-1` cuando el cliente no tiene vendedor o el documento no está
/// en la lista (en cuyo caso se pinta con [ClientMapPalette.unassigned]).
int sellerColorIndex(
  dynamic document,
  List<String> sortedSellerDocuments,
) {
  final normalized = normalizeDocument(document);
  if (normalized == null || sortedSellerDocuments.isEmpty) return -1;
  final index = sortedSellerDocuments.indexOf(normalized);
  if (index < 0) return -1;
  return index % ClientMapPalette.length;
}

/// Color estable del vendedor [document] para los marcadores de clientes.
///
/// Los clientes sin vendedor (o con un documento desconocido) usan gris.
Color clientMarkerColor(
  dynamic document,
  List<String> sortedSellerDocuments,
) {
  final index = sellerColorIndex(document, sortedSellerDocuments);
  if (index < 0) return ClientMapPalette.unassigned;
  return ClientMapPalette.colors[index];
}

/// Indica si un cliente pasa el filtro de vendedor [filter].
///
/// [filter] usa [sellerFilterAll] para todos, [sellerFilterUnassigned] para
/// clientes sin vendedor, o el documento del vendedor seleccionado.
bool clientMatchesSellerFilter(
  Map<String, dynamic> client,
  String filter,
) {
  if (filter == sellerFilterAll) return true;
  final document = normalizeDocument(client['document_employee']);
  if (filter == sellerFilterUnassigned) return document == null;
  return document == filter;
}

/// Nombre visible de un cliente en el mapa y en el bottom sheet.
String clientBusinessName(Map<String, dynamic> client) {
  final business = client['business_name']?.toString().trim() ?? '';
  if (business.isNotEmpty) return business;

  final parts = <String>[
    client['client_name1']?.toString().trim() ?? '',
    client['client_last_name1']?.toString().trim() ?? '',
  ].where((part) => part.isNotEmpty);

  return parts.isEmpty ? 'Cliente' : parts.join(' ');
}
