import 'package:flutter_test/flutter_test.dart';
import 'package:mister_chef/services/api_service.dart';

void main() {
  group('parseApiResponse', () {
    test('200 con JSON válido devuelve el objeto decodificado', () {
      final res = parseApiResponse(200, '{"message":"ok","id":7}');

      expect(res, isA<Map<String, dynamic>>());
      expect((res as Map<String, dynamic>)['message'], 'ok');
      expect(res['id'], 7);
    });

    test('200 con body vacío devuelve un mapa vacío', () {
      expect(parseApiResponse(200, ''), isEmpty);
      expect(parseApiResponse(204, '   '), isEmpty);
    });

    test('401 conserva el message enviado por el back', () {
      expect(
        () => parseApiResponse(401, '{"message":"Unauthenticated."}'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Unauthenticated.'),
        ),
      );
    });

    test('429 devuelve el mensaje de demasiados intentos', () {
      expect(
        () => parseApiResponse(429, '{"message":"Too Many Attempts."}'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having(
                (e) => e.message,
                'message',
                'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
              ),
        ),
      );
    });

    test('500 con HTML no lanza FormatException', () {
      expect(
        () => parseApiResponse(
          500,
          '<html><body><h1>Internal Server Error</h1></body></html>',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having(
                (e) => e.message,
                'message',
                'Respuesta inesperada del servidor (código 500)',
              ),
        ),
      );
    });

    test('502 con body vacío devuelve el mensaje de problema del servidor', () {
      expect(
        () => parseApiResponse(502, ''),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having(
                (e) => e.message,
                'message',
                'El servidor tuvo un problema. Inténtalo más tarde.',
              ),
        ),
      );
    });

    test('200 con JSON mal formado no lanza FormatException', () {
      expect(
        () => parseApiResponse(200, '{"message": '),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 200)
              .having(
                (e) => e.message,
                'message',
                'Respuesta inesperada del servidor (código 200)',
              ),
        ),
      );
    });

    test('error con message del back conserva el texto del servidor', () {
      expect(
        () => parseApiResponse(400, '{"message":"Datos inválidos"}'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Datos inválidos'),
        ),
      );
    });
  });
}
