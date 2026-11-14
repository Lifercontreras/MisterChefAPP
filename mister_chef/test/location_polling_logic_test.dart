import 'package:flutter_test/flutter_test.dart';
import 'package:mister_chef/config/location_polling_logic.dart';

void main() {
  group('shouldRunLocationPoll', () {
    test('corre cuando no hay petición en vuelo y la app está visible', () {
      expect(
        shouldRunLocationPoll(requestInFlight: false, appPaused: false),
        isTrue,
      );
    });

    test('no corre si la petición anterior sigue en vuelo', () {
      expect(
        shouldRunLocationPoll(requestInFlight: true, appPaused: false),
        isFalse,
      );
    });

    test('no corre si la app está en pausa', () {
      expect(
        shouldRunLocationPoll(requestInFlight: false, appPaused: true),
        isFalse,
      );
    });

    test('no corre si está en pausa y además hay una petición en vuelo', () {
      expect(
        shouldRunLocationPoll(requestInFlight: true, appPaused: true),
        isFalse,
      );
    });
  });
}
