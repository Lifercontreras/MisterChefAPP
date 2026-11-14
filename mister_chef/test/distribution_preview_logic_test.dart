import 'package:flutter_test/flutter_test.dart';
import 'package:mister_chef/config/distribution_preview_logic.dart';

Map<String, dynamic> _client({
  dynamic previous,
  String business = 'Tienda',
}) => <String, dynamic>{
  'id_client': 1,
  'business_name': business,
  'address': 'Calle 1 #2-3',
  'previous_document_employee': previous,
};

Map<String, dynamic> _seller({
  required dynamic document,
  String name = 'Vendedor',
  int currentClients = 0,
  int newClients = 0,
  List<Map<String, dynamic>> clients = const [],
}) => <String, dynamic>{
  'document_employee': document,
  'name': name,
  'current_clients': currentClients,
  'new_clients': newClients,
  'clients': clients,
};

Map<String, dynamic> _preview({
  required List<Map<String, dynamic>> sellers,
  List<Map<String, dynamic>> skipped = const [],
}) => <String, dynamic>{
  'fingerprint': 'abc123',
  'summary': {
    'clients': sellers.fold<int>(
      0,
      (total, seller) => total + (seller['clients'] as List).length,
    ),
    'sellers': sellers.length,
    'skipped_without_coordinates': skipped.length,
  },
  'sellers': sellers,
  'skipped': skipped,
};

void main() {
  group('clasificación de clientes', () {
    test('previous null es una asignación nueva', () {
      expect(
        classifyClientChange(_client(previous: null), '200'),
        ClientAssignmentChange.newAssignment,
      );
      expect(
        classifyClientChange(_client(previous: ''), '200'),
        ClientAssignmentChange.newAssignment,
      );
    });

    test('el mismo vendedor no cambia', () {
      expect(
        classifyClientChange(_client(previous: 200), '200'),
        ClientAssignmentChange.unchanged,
      );
    });

    test('un vendedor distinto es un cambio de vendedor', () {
      expect(
        classifyClientChange(_client(previous: 100), '200'),
        ClientAssignmentChange.sellerChanged,
      );
    });

    test('documentos numéricos y de texto se comparan igual', () {
      expect(
        classifyClientChange(_client(previous: 200), '200'),
        ClientAssignmentChange.unchanged,
      );
      expect(
        classifyClientChange(_client(previous: '200'), 200),
        ClientAssignmentChange.unchanged,
      );
    });
  });

  group('conteo de cambios', () {
    final preview = _preview(
      sellers: [
        _seller(
          document: 200,
          name: 'Ana Vendedora',
          currentClients: 2,
          newClients: 3,
          clients: [
            _client(previous: 200, business: 'Sin cambio'),
            _client(previous: 100, business: 'Cambia'),
            _client(previous: null, business: 'Nuevo'),
            _client(previous: '', business: 'Nuevo vacío'),
            _client(previous: 300, business: 'Cambia dos'),
          ],
        ),
      ],
    );

    test('cuenta por separado reasignados y nuevos', () {
      expect(countSellerChangedClients(preview), 2);
      expect(countNewAssignmentClients(preview), 2);
    });

    test('el total de asignaciones cambiadas incluye los nuevos', () {
      expect(countClientsWithChangedAssignment(preview), 4);
    });

    test('un vendedor sin clientes nuevos cuenta 0', () {
      final sinNuevos = _preview(
        sellers: [
          _seller(
            document: '300',
            name: 'Luis',
            currentClients: 4,
            newClients: 0,
            clients: [_client(previous: '300')],
          ),
        ],
      );

      expect(countNewAssignmentClients(sinNuevos), 0);
      expect(countSellerChangedClients(sinNuevos), 0);
      expect(countClientsWithChangedAssignment(sinNuevos), 0);
    });

    test('una vista previa sin omitidos devuelve una lista vacía', () {
      expect(previewSkipped(preview), isEmpty);
    });
  });

  group('vista previa y nombres', () {
    test('incluye a todos los vendedores aunque reciban 0 clientes', () {
      final preview = _preview(
        sellers: [
          _seller(document: '100', name: 'Ana'),
          _seller(document: '200', name: 'Luis', clients: []),
        ],
      );

      expect(previewSellers(preview).length, 2);
      expect(previewSellers(preview).last['new_clients'], 0);
    });

    test('usa name o arma el nombre completo del vendedor', () {
      expect(sellerFullName({'name': 'Ana Pérez'}), 'Ana Pérez');
      expect(
        sellerFullName({
          'name_1': 'Ana',
          'name_2': '',
          'last_name_1': 'Pérez',
          'last_name_2': 'Gómez',
        }),
        'Ana Pérez Gómez',
      );
      expect(sellerFullName({'document_employee': 200}), 'Vendedor 200');
      expect(sellerFullName({}), 'Vendedor');
    });

    test('el nombre del cliente prefiere el negocio', () {
      expect(
        clientPreviewName({'business_name': 'Panadería', 'address': 'Calle 1'}),
        'Panadería',
      );
      expect(clientPreviewName({'business_name': '', 'address': 'Calle 1'}),
          'Calle 1');
      expect(clientPreviewName({}), 'Cliente');
    });
  });
}
