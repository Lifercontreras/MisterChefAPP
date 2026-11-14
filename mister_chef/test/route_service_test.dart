import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mister_chef/services/api_service.dart';
import 'package:mister_chef/services/route_service.dart';

/// Polilínea de ejemplo del formato Encoded Polyline (precisión 5).
///
/// Decodifica a (38.5, -120.2), (40.7, -120.95) y (43.252, -126.453).
const String _encodedPolyline = r'_p~iF~ps|U_ulLnnqC_mqNvxq`@';

/// Respuesta válida de OSRM.
http.Response _okResponse([String geometry = _encodedPolyline]) {
  return http.Response(
    jsonEncode({
      'code': 'Ok',
      'routes': [
        {'geometry': geometry, 'distance': 1200.0, 'duration': 300.0},
      ],
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('RouteService.getRoadRoute', () {
    test('respuesta Ok decodifica la polilínea en puntos lat/lng', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return _okResponse();
      });

      final service = RouteService(client: client);
      final points = await service.getRoadRoute([
        {'lat': 38.5, 'lng': -120.2},
        {'lat': 43.252, 'lng': -126.453},
      ]);

      expect(requests, hasLength(1));
      expect(points, hasLength(3));
      expect(points[0]['lat'], closeTo(38.5, 1e-6));
      expect(points[0]['lng'], closeTo(-120.2, 1e-6));
      expect(points[1]['lat'], closeTo(40.7, 1e-6));
      expect(points[1]['lng'], closeTo(-120.95, 1e-6));
      expect(points[2]['lat'], closeTo(43.252, 1e-6));
      expect(points[2]['lng'], closeTo(-126.453, 1e-6));
    });

    test('la URL pone longitud antes que latitud y pide la geometría '
        'completa en polyline', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _okResponse();
      });

      final service = RouteService(client: client);
      await service.getRoadRoute([
        {'lat': 38.5, 'lng': -120.2},
        {'lat': 43.252, 'lng': -126.453},
      ]);

      expect(captured, isNotNull);
      expect(captured!.method, 'GET');
      expect(captured!.url.host, 'router.project-osrm.org');
      expect(
        captured!.url.path,
        '/route/v1/driving/-120.200000,38.500000;-126.453000,43.252000',
      );
      expect(captured!.url.queryParameters['overview'], 'full');
      expect(captured!.url.queryParameters['geometries'], 'polyline');
    });

    test('envía el User-Agent que identifica a la app', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _okResponse();
      });

      final service = RouteService(client: client);
      await service.getRoadRoute([
        {'lat': 38.5, 'lng': -120.2},
        {'lat': 43.252, 'lng': -126.453},
      ]);

      expect(captured, isNotNull);
      expect(
        captured!.headers['User-Agent'],
        'LogiGo-MisterChef/0.1 (proyecto academico)',
      );
      expect(captured!.headers['Accept'], 'application/json');
    });

    test('con 3 puntos los envía todos en orden en la URL', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _okResponse();
      });

      final service = RouteService(client: client);
      await service.getRoadRoute([
        {'lat': 38.5, 'lng': -120.2},
        {'lat': 40.7, 'lng': -120.95},
        {'lat': 43.252, 'lng': -126.453},
      ]);

      expect(captured, isNotNull);
      expect(
        captured!.url.path,
        '/route/v1/driving/'
        '-120.200000,38.500000;'
        '-120.950000,40.700000;'
        '-126.453000,43.252000',
      );
    });

    test('"NoRoute" indica que no se encontró ruta', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'NoRoute',
            'message': 'Impossible route between points',
            'routes': <dynamic>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );

      final service = RouteService(client: client);

      await expectLater(
        service.getRoadRoute([
          {'lat': 38.5, 'lng': -120.2},
          {'lat': 43.252, 'lng': -126.453},
        ]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No se encontró una ruta entre el origen y el destino.',
          ),
        ),
      );
    });

    test('HTTP 429 avisa de demasiadas solicitudes', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'code': 'TooManyRequests'}),
          429,
          headers: {'content-type': 'application/json'},
        ),
      );

      final service = RouteService(client: client);

      await expectLater(
        service.getRoadRoute([
          {'lat': 38.5, 'lng': -120.2},
          {'lat': 43.252, 'lng': -126.453},
        ]),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e.message,
                'message',
                'Demasiadas solicitudes de ruta. '
                    'Intenta de nuevo en unos segundos.',
              )
              .having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });

    test('HTTP 500 con cuerpo HTML informa el código', () async {
      final client = MockClient(
        (_) async => http.Response(
          '<html><body>Bad Gateway</body></html>',
          500,
          headers: {'content-type': 'text/html'},
        ),
      );

      final service = RouteService(client: client);

      await expectLater(
        service.getRoadRoute([
          {'lat': 38.5, 'lng': -120.2},
          {'lat': 43.252, 'lng': -126.453},
        ]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No se pudo calcular la ruta (código 500).',
          ),
        ),
      );
    });

    test('un timeout muestra el mensaje de espera', () async {
      final client = MockClient(
        (_) async => throw TimeoutException('simulado'),
      );

      final service = RouteService(client: client);

      await expectLater(
        service.getRoadRoute([
          {'lat': 38.5, 'lng': -120.2},
          {'lat': 43.252, 'lng': -126.453},
        ]),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'El servidor tardó demasiado.',
          ),
        ),
      );
    });

    test('menos de 2 puntos lanza ApiException sin llamar a la red', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return _okResponse();
      });

      final service = RouteService(client: client);

      await expectLater(
        service.getRoadRoute(const []),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        service.getRoadRoute([
          {'lat': 38.5, 'lng': -120.2},
        ]),
        throwsA(isA<ApiException>()),
      );
      expect(called, isFalse);
    });
  });

  group('RouteService.getDirections', () {
    test('mantiene la firma de origen/destino y usa OSRM', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _okResponse();
      });

      final service = RouteService(client: client);
      final points = await service.getDirections(
        originLat: 38.5,
        originLng: -120.2,
        destLat: 43.252,
        destLng: -126.453,
      );

      expect(captured, isNotNull);
      expect(
        captured!.url.path,
        '/route/v1/driving/-120.200000,38.500000;-126.453000,43.252000',
      );
      expect(points, hasLength(3));
      expect(points.first['lat'], closeTo(38.5, 1e-6));
      expect(points.first['lng'], closeTo(-120.2, 1e-6));
    });
  });
}
