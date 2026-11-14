import 'package:flutter_test/flutter_test.dart';
import 'package:mister_chef/config/road_route_logic.dart';

void main() {
  final now = DateTime(2026, 11, 13, 10, 0, 0);

  group('shouldRequestRoadRoute', () {
    test('con menos de 2 puntos no pide nada', () {
      expect(
        shouldRequestRoadRoute(
          pointCount: 1,
          signature: 'a',
          lastSuccessSignature: null,
          lastRequestAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('con más de 50 puntos no pide nada', () {
      expect(
        shouldRequestRoadRoute(
          pointCount: 51,
          signature: 'a',
          lastSuccessSignature: null,
          lastRequestAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('con exactamente 50 puntos sí pide', () {
      expect(
        shouldRequestRoadRoute(
          pointCount: 50,
          signature: 'a',
          lastSuccessSignature: null,
          lastRequestAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('con la misma firma que la última exitosa no repite', () {
      expect(
        shouldRequestRoadRoute(
          pointCount: 3,
          signature: 'a|b|c',
          lastSuccessSignature: 'a|b|c',
          lastRequestAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('con otra firma sí pide', () {
      expect(
        shouldRequestRoadRoute(
          pointCount: 3,
          signature: 'a|b|d',
          lastSuccessSignature: 'a|b|c',
          lastRequestAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('primera petición sin lastRequestAt sí pide', () {
      expect(
        shouldRequestRoadRoute(
          pointCount: 2,
          signature: 'a|b',
          lastSuccessSignature: null,
          lastRequestAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('hace 1 s no pide por el intervalo mínimo', () {
      expect(
        shouldRequestRoadRoute(
          pointCount: 2,
          signature: 'a|b',
          lastSuccessSignature: null,
          lastRequestAt: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('hace 3 s sí pide', () {
      expect(
        shouldRequestRoadRoute(
          pointCount: 2,
          signature: 'a|b',
          lastSuccessSignature: null,
          lastRequestAt: now.subtract(const Duration(seconds: 3)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
