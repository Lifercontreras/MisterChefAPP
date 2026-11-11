import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config/constants.dart';
import 'api_service.dart';
import 'location_send_throttle.dart';
import 'location_service.dart';

/// Estado observable del rastreo de ubicación del domiciliario.
enum TrackingStatus {
  /// No se está compartiendo la ubicación.
  detenido,

  /// El stream está abierto y las posiciones se envían al servidor.
  activo,

  /// Falta el permiso de ubicación o el GPS está desactivado.
  sinPermiso,

  /// El último envío falló por red o por el servidor; se reintentará.
  errorRed,
}

/// Servicio singleton que mantiene el rastreo de ubicación del domiciliario.
///
/// Abre un único stream de posiciones con [AndroidSettings] para que Android
/// lo ejecute como servicio en primer plano con notificación persistente.
/// Cada posición se envía a la API como máximo cada 25 segundos; los fallos
/// de red no cierran el stream, solo marcan [TrackingStatus.errorRed] y el
/// siguiente envío permitido reintenta.
///
/// Es un [ChangeNotifier] para que la UI pueda observar el estado sin
/// agregar dependencias nuevas.
///
/// Limitación conocida: si Android mata el proceso de la app, la
/// notificación en primer plano del plugin también desaparece. Sin un
/// paquete de servicios en segundo plano independiente no es posible
/// sobrevivir a esa situación.
class TrackingService extends ChangeNotifier {
  TrackingService._();

  static final TrackingService _instance = TrackingService._();

  /// Instancia única del servicio.
  factory TrackingService() => _instance;

  final _locationService = LocationService();
  final _throttle = LocationSendThrottle();

  StreamSubscription<Position>? _subscription;
  bool _starting = false;
  bool _sending = false;

  TrackingStatus _status = TrackingStatus.detenido;

  /// Estado actual del rastreo.
  TrackingStatus get status => _status;

  String? _lastError;

  /// Último error registrado, o `null` si no hay ninguno.
  String? get lastError => _lastError;

  /// `true` cuando el stream está abierto y se están enviando posiciones.
  bool get isActive => _status == TrackingStatus.activo;

  /// Inicia el rastreo si todavía no está activo.
  ///
  /// Es idempotente: si ya hay un stream abierto o se está iniciando, no
  /// crea uno nuevo. Verifica el servicio de GPS y el permiso while-in-use
  /// antes de abrir el stream.
  Future<void> start() async {
    if (_subscription != null || _starting) return;

    _starting = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _updateStatus(
          TrackingStatus.sinPermiso,
          error: 'El GPS está desactivado.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _updateStatus(
          TrackingStatus.sinPermiso,
          error: 'Permiso de ubicación denegado.',
        );
        return;
      }

      // Otra llamada pudo haber abierto el stream mientras se pedía permiso.
      if (_subscription != null) return;

      _throttle.reset();
      _subscription =
          Geolocator.getPositionStream(
            locationSettings: _buildSettings(),
          ).listen(
            (position) => unawaited(_onPosition(position)),
            onError: _onStreamError,
            cancelOnError: false,
          );
      _updateStatus(TrackingStatus.activo, clearError: true);
    } catch (e) {
      final subscription = _subscription;
      _subscription = null;
      await subscription?.cancel();
      _updateStatus(TrackingStatus.errorRed, error: e.toString());
    } finally {
      _starting = false;
    }
  }

  /// Detiene el rastreo local y cancela el stream.
  ///
  /// No llama a `location/deactivate`: ese aviso al servidor se hace desde
  /// [AuthService.logout] para que siga el orden correcto antes de borrar
  /// el token.
  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    _sending = false;
    _throttle.reset();

    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (_) {
        // El stream pudo cerrarse solo; la parada local continúa igual.
      }
    }

    _updateStatus(TrackingStatus.detenido, clearError: true);
  }

  /// Configuración del stream según la plataforma.
  ///
  /// En Android incluye la notificación del servicio en primer plano. En
  /// otras plataformas usa la configuración estándar equivalente.
  LocationSettings _buildSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(
          seconds: AppConstants.locationIntervalSeconds,
        ),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Mister Chef',
          notificationText: 'Compartiendo tu ubicación con la central',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  Future<void> _onPosition(Position position) async {
    if (_subscription == null || _sending) return;

    final now = DateTime.now();
    if (!_throttle.canSend(now)) return;

    _sending = true;
    try {
      await _locationService.sendLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _throttle.markSent(now);
      if (_status != TrackingStatus.activo) {
        _updateStatus(TrackingStatus.activo, clearError: true);
      }
    } on ApiException catch (e) {
      // 401: ApiService ya limpió la sesión y main.dart detiene el servicio.
      if (e.statusCode == 401) return;

      // 403: el usuario no puede compartir ubicación. Se detiene el rastreo
      // y no se reintenta, mostrando el mensaje del back.
      if (e.statusCode == 403) {
        await stop();
        _updateStatus(TrackingStatus.sinPermiso, error: e.message);
        return;
      }

      // Cualquier otro error del servidor: mantener el stream y reintentar
      // en el próximo envío permitido.
      _updateStatus(TrackingStatus.errorRed, error: e.message);
    } catch (e) {
      // Fallo inesperado: mantener el stream y reintentar en el próximo
      // envío permitido.
      _updateStatus(TrackingStatus.errorRed, error: e.toString());
    } finally {
      _sending = false;
    }
  }

  void _onStreamError(Object error) {
    if (_subscription == null) return;
    _updateStatus(TrackingStatus.errorRed, error: error.toString());
  }

  void _updateStatus(
    TrackingStatus status, {
    String? error,
    bool clearError = false,
  }) {
    _status = status;
    if (clearError) {
      _lastError = null;
    } else if (error != null) {
      _lastError = error;
    }
    notifyListeners();
  }
}
