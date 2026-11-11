import 'package:geolocator/geolocator.dart';

/// Utilidades locales de GPS para pantallas que solo necesitan mostrar la
/// posición en el mapa.
///
/// El envío periódico de ubicación al servidor vive en `TrackingService`.
class LocationHelper {
  static final LocationHelper _instance = LocationHelper._internal();
  factory LocationHelper() => _instance;
  LocationHelper._internal();

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
  // Stream de posición en tiempo real
  // Para dibujar el rastro recorrido en el mapa
  // ══════════════════════════════════════════
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // actualiza cada 10 metros
      ),
    );
  }
}
