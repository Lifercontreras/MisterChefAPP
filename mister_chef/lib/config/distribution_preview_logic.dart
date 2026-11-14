/// Utilidades puras para interpretar la vista previa de distribución.
///
/// No dependen de Flutter ni de la red: reciben los mapas tal como los
/// devuelve la API y permiten clasificar clientes, contar cambios y construir
/// nombres visibles. Así la pantalla de vista previa y sus pruebas comparten
/// exactamente las mismas reglas.
library;

/// Clasificación de un cliente dentro de la vista previa de distribución.
enum ClientAssignmentChange {
  /// El cliente ya pertenecía al vendedor destino.
  unchanged,

  /// El cliente tenía otro vendedor y pasa al vendedor destino.
  sellerChanged,

  /// El cliente no tenía vendedor y se asigna por primera vez.
  newAssignment,
}

/// Normaliza un documento de empleado a texto no vacío.
///
/// La API puede devolver documentos como número o como string, por lo que
/// ambos casos se comparan siempre como texto. Devuelve `null` cuando el
/// valor falta o está vacío.
String? normalizeEmployeeDocument(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

/// Vendedores incluidos en la vista previa (todos los activos, incluso con 0).
List<Map<String, dynamic>> previewSellers(Map<String, dynamic> preview) =>
    _mapList(preview['sellers']);

/// Clientes omitidos de la vista previa (normalmente por falta de coordenadas).
List<Map<String, dynamic>> previewSkipped(Map<String, dynamic> preview) =>
    _mapList(preview['skipped']);

/// Clientes que recibirá un vendedor según la vista previa.
List<Map<String, dynamic>> sellerClients(Map<String, dynamic> seller) =>
    _mapList(seller['clients']);

/// Clasifica [client] respecto al vendedor destino [destinationDocument].
ClientAssignmentChange classifyClientChange(
  Map<String, dynamic> client,
  dynamic destinationDocument,
) {
  final previous = normalizeEmployeeDocument(
    client['previous_document_employee'],
  );
  if (previous == null) return ClientAssignmentChange.newAssignment;

  final destination = normalizeEmployeeDocument(destinationDocument);
  return previous == destination
      ? ClientAssignmentChange.unchanged
      : ClientAssignmentChange.sellerChanged;
}

/// Cuenta los clientes de [preview] en la clasificación [change].
int countClientsForChange(
  Map<String, dynamic> preview,
  ClientAssignmentChange change,
) {
  var count = 0;
  for (final seller in previewSellers(preview)) {
    final destination =
        normalizeEmployeeDocument(seller['document_employee']) ?? '';
    for (final client in sellerClients(seller)) {
      if (classifyClientChange(client, destination) == change) count++;
    }
  }
  return count;
}

/// Clientes que ya tenían vendedor y pasan a otro distinto.
int countSellerChangedClients(Map<String, dynamic> preview) =>
    countClientsForChange(preview, ClientAssignmentChange.sellerChanged);

/// Clientes que no tenían vendedor y se asignan por primera vez.
int countNewAssignmentClients(Map<String, dynamic> preview) =>
    countClientsForChange(preview, ClientAssignmentChange.newAssignment);

/// Clientes cuya asignación cambia: los reasignados más los nuevos.
///
/// Incluye los clientes con `previous_document_employee` nulo porque también
/// pasan de "sin vendedor" a un vendedor destino.
int countClientsWithChangedAssignment(Map<String, dynamic> preview) =>
    countSellerChangedClients(preview) + countNewAssignmentClients(preview);

/// Nombre completo visible de un vendedor.
///
/// La API de vista previa suele enviar `name`; si no viene, se arma con las
/// columnas habituales del empleado. Devuelve un texto genérico si no hay
/// ningún dato utilizable.
String sellerFullName(Map<String, dynamic> seller) {
  final name = seller['name']?.toString().trim() ?? '';
  if (name.isNotEmpty) return name;

  final fullName = seller['full_name']?.toString().trim() ?? '';
  if (fullName.isNotEmpty) return fullName;

  final parts = <String>[
    seller['name_1']?.toString().trim() ?? '',
    seller['name_2']?.toString().trim() ?? '',
    seller['last_name_1']?.toString().trim() ?? '',
    seller['last_name_2']?.toString().trim() ?? '',
  ].where((part) => part.isNotEmpty);

  if (parts.isNotEmpty) return parts.join(' ');

  final document = normalizeEmployeeDocument(seller['document_employee']);
  return document == null ? 'Vendedor' : 'Vendedor $document';
}

/// Nombre visible de un cliente: prefiere el negocio y usa la dirección o un
/// texto genérico como respaldo.
String clientPreviewName(Map<String, dynamic> client) {
  final business = client['business_name']?.toString().trim() ?? '';
  if (business.isNotEmpty) return business;

  final address = client['address']?.toString().trim() ?? '';
  if (address.isNotEmpty) return address;

  return 'Cliente';
}
