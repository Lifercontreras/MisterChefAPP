import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mister_chef/services/api_service.dart';
import 'package:mister_chef/services/route_service.dart';

/// Key ficticia para las pruebas; nunca es una key real.
const String _testApiKey = 'clave-de-prueba';

/// Polilínea de ejemplo de la documentación de Google.
///
/// Decodifica a (38.5, -120.2), (40.7, -120.95) y (43.252, -126.453).
const String _encodedPolyline = r'_p~iF~ps|U_ulLnnqC_mqNvxq`@';

void main() {
  group('RouteService.getDirections', () {
    test(
      '200 válido envía los headers correctos y decodifica la polilínea',
      () async {
        http.Request? captured;

        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'routes': [
                {
                  'polyline': {'encodedPolyline': _encodedPolyline},
                  'distanceMeters': 1200,
                  'duration': '300s',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = RouteService(client: client, apiKey: _testApiKey);
        final points = await service.getDirections(
          originLat: 38.5,
          originLng: -120.2,
          destLat: 43.252,
          destLng: -126.453,
        );

        expect(captured, isNotNull);
        expect(captured!.method, 'POST');
        expect(
          captured!.url.toString(),
          'https://routes.googleapis.com/directions/v2:computeRoutes',
        );
        expect(captured!.headers['Content-Type'], 'application/json');
        expect(captured!.headers['X-Goog-Api-Key'], _testApiKey);
        expect(
          captured!.headers['X-Goog-FieldMask'],
          'routes.polyline.encodedPolyline,'
          'routes.distanceMeters,'
          'routes.duration',
        );

        final body = jsonDecode(captured!.body) as Map<String, dynamic>;
        expect(body['travelMode'], 'DRIVE');
        expect(body['routingPreference'], 'TRAFFIC_UNAWARE');
        expect(body['polylineEncoding'], 'ENCODED_POLYLINE');
        expect(body['origin']['location']['latLng']['latitude'], 38.5);
        expect(body['origin']['location']['latLng']['longitude'], -120.2);
        expect(body['destination']['location']['latLng']['latitude'], 43.252);
        expect(
          body['destination']['location']['latLng']['longitude'],
          -126.453,
        );

        expect(points, hasLength(3));
        expect(points[0]['lat'], closeTo(38.5, 1e-6));
        expect(points[0]['lng'], closeTo(-120.2, 1e-6));
        expect(points[1]['lat'], closeTo(40.7, 1e-6));
        expect(points[1]['lng'], closeTo(-120.95, 1e-6));
        expect(points[2]['lat'], closeTo(43.252, 1e-6));
        expect(points[2]['lng'], closeTo(-126.453, 1e-6));
      },
    );

    test('403 con error.message lo muestra al usuario', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 403,
              'message': 'Routes API has not been used in project before.',
              'status': 'PERMISSION_DENIED',
            },
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );

      final service = RouteService(client: client, apiKey: _testApiKey);

      await expectLater(
        service.getDirections(
          originLat: 38.5,
          originLng: -120.2,
          destLat: 43.252,
          destLng: -126.453,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.message,
                'message',
                contains('Routes API has not been used in project before.'),
              )
              .having(
                (e) => e.message,
                'message',
                contains('PERMISSION_DENIED'),
              ),
        ),
      );
    });

    test('200 con routes vacío indica que no se encontró ruta', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'routes': <dynamic>[]}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final service = RouteService(client: client, apiKey: _testApiKey);

      await expectLater(
        service.getDirections(
          originLat: 38.5,
          originLng: -120.2,
          destLat: 43.252,
          destLng: -126.453,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No se encontró una ruta entre el origen y el destino.',
          ),
        ),
      );
    });

    test(
      'key vacía lanza DirectionsApiKeyMissingException sin llamar a la red',
      () async {
        var called = false;

        final client = MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        });

        final service = RouteService(client: client, apiKey: '');

        await expectLater(
          service.getDirections(
            originLat: 38.5,
            originLng: -120.2,
            destLat: 43.252,
            destLng: -126.453,
          ),
          throwsA(isA<DirectionsApiKeyMissingException>()),
        );
        expect(called, isFalse);
      },
    );
  });
}
