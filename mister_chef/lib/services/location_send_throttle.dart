import '../config/constants.dart';

/// Regla pura que decide cuándo se puede enviar una nueva posición GPS
/// al servidor.
///
/// Se mantiene separada de [TrackingService] para poder probarla sin
/// plugins ni peticiones de red. Solo recuerda el instante del último
/// envío exitoso: si un envío falla no se registra, de modo que el
/// siguiente intento ocurra en la siguiente posición permitida.
class LocationSendThrottle {
  /// Crea la regla con un intervalo mínimo entre envíos.
  ///
  /// Por defecto [AppConstants.locationMinSendInterval] (8 s), un margen
  /// menor que el intervalo del stream ([AppConstants.locationUpdateInterval],
  /// 10 s) para no perder posiciones por pequeñas diferencias de reloj.
  LocationSendThrottle({
    this.minimumInterval = AppConstants.locationMinSendInterval,
  });

  /// Tiempo mínimo que debe transcurrir entre dos envíos exitosos.
  final Duration minimumInterval;

  DateTime? _lastSentAt;

  /// Indica si se puede enviar una posición en el instante [now].
  ///
  /// Devuelve `true` si nunca se ha enviado nada o si ya pasó el
  /// intervalo mínimo desde el último envío exitoso.
  bool canSend(DateTime now) {
    final last = _lastSentAt;
    if (last == null) return true;
    return now.difference(last) >= minimumInterval;
  }

  /// Registra un envío exitoso en el instante [sentAt].
  void markSent(DateTime sentAt) {
    _lastSentAt = sentAt;
  }

  /// Olvida el último envío (por ejemplo, al reiniciar el rastreo).
  void reset() {
    _lastSentAt = null;
  }
}
