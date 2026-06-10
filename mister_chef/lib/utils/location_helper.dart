import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../config/constants.dart';
import '../services/location_service.dart';

class LocationHelper {
  static final LocationHelper _instance = LocationHelper._internal();
  factory LocationHelper() => _instance;
  LocationHelper._internal();

  final _locationService = LocationService();
  Timer? _timer;
  bool _isTracking = false;

  // ── Verificar y pedir permisos de GPS
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  // ── Obtener posición actual una sola vez
  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════
  // Iniciar envío periódico de ubicación al servidor
  // Llama POST /location cada 30 segundos
  // Solo para el VENDEDOR (type = 'V')
  // ══════════════════════════════════════════
  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return;

    _isTracking = true;

    // Enviar posición inmediatamente al iniciar
    await _sendCurrentLocation();

    // Luego cada 30 segundos
    _timer = Timer.periodic(
      Duration(seconds: AppConstants.locationIntervalSeconds),
      (_) => _sendCurrentLocation(),
    );
  }

  // ── Detener el envío periódico
  Future<void> stopTracking() async {
    _timer?.cancel();
    _timer = null;
    _isTracking = false;

    // Notificar al servidor que el domiciliario terminó su jornada
    try {
      await _locationService.deactivateLocation();
    } catch (_) {
      // Si falla, igual detenemos el tracking local
    }
  }

  // ── Enviar posición actual al servidor
  Future<void> _sendCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _locationService.sendLocation(
        latitude:  position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Silencioso — si falla una actualización se reintenta en 30 seg
    }
  }

  bool get isTracking => _isTracking;

  // ══════════════════════════════════════════
  // Stream de posición en tiempo real
  // Para dibujar el rastro recorrido en el mapa
  // ══════════════════════════════════════════
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:          LocationAccuracy.high,
        distanceFilter:    10, // actualiza cada 10 metros
      ),
    );
  }
}