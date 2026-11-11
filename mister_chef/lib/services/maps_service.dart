import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/app_colors.dart';

/// MapsService centraliza todo lo relacionado con:
/// 1. Permisos y obtención de GPS
/// 2. Construcción de marcadores y polilíneas para Google Maps
class MapsService {
  static final MapsService _instance = MapsService._internal();
  factory MapsService() => _instance;
  MapsService._internal();

  // ══════════════════════════════════════════
  // PERMISOS Y POSICIÓN GPS
  // ══════════════════════════════════════════

  /// Verifica y solicita permisos de ubicación.
  /// Devuelve true si los permisos fueron concedidos.
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

  /// Obtiene la posición actual del dispositivo una sola vez.
  /// Devuelve null si no hay permisos o el GPS falla.
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

  /// Obtiene la posición como LatLng listo para Google Maps.
  Future<LatLng?> getCurrentLatLng() async {
    final position = await getCurrentPosition();
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  // ══════════════════════════════════════════
  // CONSTRUCCIÓN DE MARCADORES
  // ══════════════════════════════════════════

  /// Construye marcadores para la ruta del vendedor.
  /// Recibe la lista de clientes del endpoint GET /routes.
  /// Cada cliente debe tener: latitude, longitude, business_name/client_name1, address
  Set<Marker> buildClientMarkers({
    required List<Map<String, dynamic>> clients,
    required void Function(Map<String, dynamic>) onTap,
  }) {
    final markers = <Marker>{};

    for (int i = 0; i < clients.length; i++) {
      final c = clients[i];
      final lat = double.tryParse(c['latitude']?.toString() ?? '');
      final lng = double.tryParse(c['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      final nombre = (c['business_name'] ?? c['client_name1'] ?? '').toString();

      markers.add(
        Marker(
          markerId: MarkerId('client_$i'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: nombre, snippet: c['address'] ?? ''),
          onTap: () => onTap(c),
        ),
      );
    }

    return markers;
  }

  /// Construye marcadores para el mapa del administrador.
  /// Recibe la lista de domiciliarios activos del endpoint GET /location.
  /// Cada domiciliario tiene: document_employee, name, latitude, longitude, last_update
  Set<Marker> buildEmployeeMarkers({
    required List<Map<String, dynamic>> employees,
    required void Function(Map<String, dynamic>) onTap,
  }) {
    final markers = <Marker>{};

    for (int i = 0; i < employees.length; i++) {
      final e = employees[i];
      final lat = double.tryParse(e['latitude']?.toString() ?? '');
      final lng = double.tryParse(e['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId('emp_${e['document_employee']}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: e['name'] ?? 'Domiciliario',
            snippet: _formatLastUpdate(e['last_update']),
          ),
          onTap: () => onTap(e),
        ),
      );
    }

    return markers;
  }

  // ══════════════════════════════════════════
  // CONSTRUCCIÓN DE POLILÍNEA
  // ══════════════════════════════════════════

  /// Construye la polilínea que conecta los clientes en la ruta del vendedor.
  Set<Polyline> buildRoutePolyline(List<Map<String, dynamic>> clients) {
    final points = <LatLng>[];

    for (final c in clients) {
      final lat = double.tryParse(c['latitude']?.toString() ?? '');
      final lng = double.tryParse(c['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;
      points.add(LatLng(lat, lng));
    }

    if (points.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId('ruta_vendedor'),
        points: points,
        color: AppColors.mapRoute,
        width: 3,
        patterns: [PatternItem.dash(12), PatternItem.gap(6)],
      ),
    };
  }

  // ══════════════════════════════════════════
  // CÁMARA DEL MAPA
  // ══════════════════════════════════════════

  /// Anima la cámara del mapa hacia una posición específica.
  Future<void> moveCameraTo(
    GoogleMapController controller,
    LatLng target, {
    double zoom = 15,
  }) async {
    await controller.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  /// Ajusta la cámara para mostrar todos los marcadores (bounds).
  Future<void> fitBounds(
    GoogleMapController controller,
    List<LatLng> points,
  ) async {
    if (points.isEmpty) return;
    if (points.length == 1) {
      await moveCameraTo(controller, points.first);
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80, // padding en píxeles
      ),
    );
  }

  // ══════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════

  /// Parsea latitude/longitude desde string o num a double.
  static double? parseCoord(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatLastUpdate(String? dateStr) {
    if (dateStr == null) return 'Sin actualización';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    return 'Hace ${diff.inHours}h';
  }
}
