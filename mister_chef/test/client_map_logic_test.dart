import 'package:flutter_test/flutter_test.dart';
import 'package:mister_chef/config/client_map_logic.dart';

void main() {
  group('color estable por vendedor', () {
    test('el orden de llegada no cambia la lista ni el índice de color', () {
      final llegadaA = buildSortedSellerDocuments([300, 100, 200]);
      final llegadaB = buildSortedSellerDocuments(['200', '300', '100']);

      expect(llegadaA, ['100', '200', '300']);
      expect(llegadaB, llegadaA);

      expect(sellerColorIndex('100', llegadaA), 0);
      expect(sellerColorIndex('200', llegadaB), 1);
      expect(sellerColorIndex('300', llegadaA), 2);
    });

    test('el mismo vendedor recibe siempre el mismo color', () {
      final vendedores = buildSortedSellerDocuments(['100', '200', '300']);

      final colorA = clientMarkerColor('200', vendedores);
      final colorB = clientMarkerColor('200', vendedores);

      expect(colorA, colorB);
      expect(colorA, ClientMapPalette.colors[1]);
    });

    test('los clientes sin vendedor usan gris', () {
      final vendedores = buildSortedSellerDocuments(['100']);

      expect(clientMarkerColor(null, vendedores), ClientMapPalette.unassigned);
      expect(clientMarkerColor('', vendedores), ClientMapPalette.unassigned);
      expect(clientMarkerColor('  ', vendedores), ClientMapPalette.unassigned);
    });

    test('un documento desconocido también usa gris', () {
      final vendedores = buildSortedSellerDocuments(['100']);

      expect(
        clientMarkerColor('999', vendedores),
        ClientMapPalette.unassigned,
      );
    });

    test('la paleta rota cada 8 vendedores', () {
      final vendedores = buildSortedSellerDocuments([
        '01', '02', '03', '04', '05', '06', '07', '08', '09',
      ]);

      expect(sellerColorIndex('01', vendedores), 0);
      expect(sellerColorIndex('08', vendedores), 7);
      expect(sellerColorIndex('09', vendedores), 0);
    });
  });

  group('filtro por vendedor', () {
    final conVendedor = <String, dynamic>{
      'id_client': 1,
      'document_employee': 200,
    };
    final sinVendedor = <String, dynamic>{
      'id_client': 2,
      'document_employee': null,
    };

    test('Todos incluye clientes con y sin vendedor', () {
      expect(clientMatchesSellerFilter(conVendedor, sellerFilterAll), isTrue);
      expect(clientMatchesSellerFilter(sinVendedor, sellerFilterAll), isTrue);
    });

    test('un vendedor específico solo incluye sus clientes', () {
      expect(clientMatchesSellerFilter(conVendedor, '200'), isTrue);
      expect(clientMatchesSellerFilter(conVendedor, '100'), isFalse);
      expect(clientMatchesSellerFilter(sinVendedor, '200'), isFalse);
    });

    test('Sin asignar solo incluye clientes sin vendedor', () {
      expect(
        clientMatchesSellerFilter(conVendedor, sellerFilterUnassigned),
        isFalse,
      );
      expect(
        clientMatchesSellerFilter(sinVendedor, sellerFilterUnassigned),
        isTrue,
      );
      expect(
        clientMatchesSellerFilter(
          {'id_client': 3, 'document_employee': ''},
          sellerFilterUnassigned,
        ),
        isTrue,
      );
    });
  });

  group('nombre visible del cliente', () {
    test('prefiere el nombre del negocio', () {
      expect(
        clientBusinessName({
          'business_name': 'Panadería La Esquina',
          'client_name1': 'Ana',
        }),
        'Panadería La Esquina',
      );
    });

    test('usa el nombre cuando no hay negocio', () {
      expect(
        clientBusinessName({
          'business_name': null,
          'client_name1': 'Ana',
          'client_last_name1': 'Pérez',
        }),
        'Ana Pérez',
      );
    });

    test('devuelve un texto genérico si no hay ningún nombre', () {
      expect(clientBusinessName({}), 'Cliente');
    });
  });
}
