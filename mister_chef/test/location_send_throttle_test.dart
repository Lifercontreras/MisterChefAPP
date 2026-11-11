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

    test('dos posiciones con 10 s de diferencia envían solo la primera', () {
      final throttle = LocationSendThrottle();

      expect(throttle.canSend(t0), isTrue);
      throttle.markSent(t0);

      expect(throttle.canSend(t0.add(const Duration(seconds: 10))), isFalse);
    });

    test('dos posiciones con 30 s de diferencia envían ambas', () {
      final throttle = LocationSendThrottle();

      expect(throttle.canSend(t0), isTrue);
      throttle.markSent(t0);

      expect(throttle.canSend(t0.add(const Duration(seconds: 30))), isTrue);
    });

    test('justo a los 25 s se permite el siguiente envío', () {
      final throttle = LocationSendThrottle();
      throttle.markSent(t0);

      expect(throttle.canSend(t0.add(const Duration(seconds: 24))), isFalse);
      expect(throttle.canSend(t0.add(const Duration(seconds: 25))), isTrue);
    });

    test('tras un fallo se reintenta en la siguiente posición permitida', () {
      final throttle = LocationSendThrottle();

      // Envío exitoso inicial.
      expect(throttle.canSend(t0), isTrue);
      throttle.markSent(t0);

      // A los 10 s hay una posición, pero la regla la descarta.
      // Supongamos que además el envío falla: no se marca como enviado.
      expect(throttle.canSend(t0.add(const Duration(seconds: 10))), isFalse);

      // A los 30 s se permite reintentar con la nueva posición.
      expect(throttle.canSend(t0.add(const Duration(seconds: 30))), isTrue);
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
