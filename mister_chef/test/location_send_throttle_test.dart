import 'package:flutter_test/flutter_test.dart';
import 'package:mister_chef/services/location_send_throttle.dart';

void main() {
  // Instante base fijo para que las pruebas sean deterministas.
  final t0 = DateTime(2026, 1, 1, 12, 0, 0);

  group('LocationSendThrottle', () {
    test('el primer envío siempre está permitido', () {
      final throttle = LocationSendThrottle();

      expect(throttle.canSend(t0), isTrue);
    });

    test('dos posiciones con 7 s de diferencia envían solo la primera', () {
      final throttle = LocationSendThrottle();

      expect(throttle.canSend(t0), isTrue);
      throttle.markSent(t0);

      expect(throttle.canSend(t0.add(const Duration(seconds: 7))), isFalse);
    });

    test('dos posiciones con 30 s de diferencia envían ambas', () {
      final throttle = LocationSendThrottle();

      expect(throttle.canSend(t0), isTrue);
      throttle.markSent(t0);

      expect(throttle.canSend(t0.add(const Duration(seconds: 30))), isTrue);
    });

    test('justo a los 8 s se permite el siguiente envío', () {
      final throttle = LocationSendThrottle();
      throttle.markSent(t0);

      expect(throttle.canSend(t0.add(const Duration(seconds: 7))), isFalse);
      expect(throttle.canSend(t0.add(const Duration(seconds: 8))), isTrue);
    });

    test('a los 8 s se permite el envío', () {
      final throttle = LocationSendThrottle();
      throttle.markSent(t0);

      expect(throttle.canSend(t0.add(const Duration(seconds: 8))), isTrue);
    });

    test('a los 7 s no se permite el envío', () {
      final throttle = LocationSendThrottle();
      throttle.markSent(t0);

      expect(throttle.canSend(t0.add(const Duration(seconds: 7))), isFalse);
    });

    test('un envío fallido no avanza el reloj', () {
      final throttle = LocationSendThrottle();
      throttle.markSent(t0);

      // A los 8 s se permite intentar, pero el envío falla: no se llama a
      // markSent, así que el último envío exitoso sigue siendo t0.
      expect(throttle.canSend(t0.add(const Duration(seconds: 8))), isTrue);

      // Un segundo después sigue permitido porque el fallo no movió el reloj.
      expect(throttle.canSend(t0.add(const Duration(seconds: 9))), isTrue);
      expect(throttle.canSend(t0.add(const Duration(seconds: 7))), isFalse);
    });

    test('tras un fallo se reintenta en la siguiente posición permitida', () {
      final throttle = LocationSendThrottle();

      // Envío exitoso inicial.
      expect(throttle.canSend(t0), isTrue);
      throttle.markSent(t0);

      // A los 7 s hay una posición, pero la regla la descarta.
      // Supongamos que además el envío falla: no se marca como enviado.
      expect(throttle.canSend(t0.add(const Duration(seconds: 7))), isFalse);

      // A los 10 s se permite reintentar con la nueva posición.
      expect(throttle.canSend(t0.add(const Duration(seconds: 10))), isTrue);
    });

    test('reset vuelve a permitir un envío inmediato', () {
      final throttle = LocationSendThrottle();
      throttle.markSent(t0);
      expect(throttle.canSend(t0.add(const Duration(seconds: 5))), isFalse);

      throttle.reset();

      expect(throttle.canSend(t0.add(const Duration(seconds: 5))), isTrue);
    });
  });
}
