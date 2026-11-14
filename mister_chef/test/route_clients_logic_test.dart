import 'package:flutter_test/flutter_test.dart';
import 'package:mister_chef/config/route_clients_logic.dart';

void main() {
  group('activeRouteClients', () {
    test('descarta status false, 0, 0.0, "0" y "false"', () {
      final clients = <Map<String, dynamic>>[
        {'id_client': 1, 'status': false},
        {'id_client': 2, 'status': 0},
        {'id_client': 3, 'status': 0.0},
        {'id_client': 4, 'status': '0'},
        {'id_client': 5, 'status': 'false'},
      ];

      expect(activeRouteClients(clients), isEmpty);
    });

    test('conserva status true, 1, "1" y "true"', () {
      final clients = <Map<String, dynamic>>[
        {'id_client': 1, 'status': true},
        {'id_client': 2, 'status': 1},
        {'id_client': 3, 'status': '1'},
        {'id_client': 4, 'status': 'true'},
      ];

      final result = activeRouteClients(clients);

      expect(result, hasLength(4));
      expect(result.map((c) => c['id_client']), [1, 2, 3, 4]);
    });

    test('tolera mayúsculas y espacios en el texto', () {
      expect(
        activeRouteClients(<Map<String, dynamic>>[
          {'status': ' FALSE '},
        ]),
        isEmpty,
      );
      expect(
        activeRouteClients(<Map<String, dynamic>>[
          {'status': 'TRUE'},
        ]),
        hasLength(1),
      );
    });

    test('conserva status null y clientes sin campo status', () {
      final clients = <Map<String, dynamic>>[
        {'id_client': 1, 'status': null},
        {'id_client': 2},
      ];

      final result = activeRouteClients(clients);

      expect(result, hasLength(2));
      expect(result.map((c) => c['id_client']), [1, 2]);
    });

    test('lista vacía devuelve lista vacía', () {
      expect(activeRouteClients(<Map<String, dynamic>>[]), isEmpty);
    });

    test('preserva el orden y los datos de los clientes activos', () {
      final clients = <Map<String, dynamic>>[
        {'id_client': 1, 'business_name': 'Uno', 'status': true},
        {'id_client': 2, 'business_name': 'Dos', 'status': false},
        {'id_client': 3, 'business_name': 'Tres', 'status': 1},
      ];

      final result = activeRouteClients(clients);

      expect(result, hasLength(2));
      expect(result[0]['business_name'], 'Uno');
      expect(result[1]['business_name'], 'Tres');
    });

    test('no modifica la lista original', () {
      final clients = <Map<String, dynamic>>[
        {'id_client': 1, 'status': true},
        {'id_client': 2, 'status': false},
      ];

      activeRouteClients(clients);

      expect(clients, hasLength(2));
    });
  });
}
