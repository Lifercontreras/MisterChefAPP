import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/road_route_logic.dart';
import '../../config/route_clients_logic.dart';
import '../../services/route_service.dart';
import '../../services/api_service.dart';
import '../../utils/location_helper.dart';
import '../../widgets/role_bottom_nav.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final _routeService = RouteService();
  final _locationHelper = LocationHelper();

  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;
  bool _hasGpsFix = false;
  final List<LatLng> _trackedPath = [];
  StreamSubscription<Position>? _positionStream;

  // Ruta general por vías (OSRM). El contador de versión descarta respuestas
  // que llegan después de que la lista de clientes ya cambió.
  int _roadRouteVersion = 0;
  bool _roadRouteRequestInFlight = false;
  String? _roadRouteSuccessSignature;
  DateTime? _roadRouteLastRequestAt;
  List<LatLng>? _roadRoutePoints;
  List<LatLng>? _latestRoadPoints;
  bool _hasRoadRoute = false;

  static const double _panelMin = 0.18;
  static const double _panelInitial = 0.42;
  static const double _panelMax = 0.72;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _loadRoutes();
    await _initMap();
    _startPositionStream();
  }

  Future<void> _initMap() async {
    final position = await _locationHelper.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 13),
      );
    }
  }

  void _startPositionStream() {
    _positionStream = _locationHelper.getPositionStream().listen((position) {
      final newPos = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentPosition = newPos;
          _hasGpsFix = true;
          _trackedPath.add(newPos);
          _updateTrackedPolyline();
        });
        _mapController.future.then((ctrl) {
          ctrl.animateCamera(CameraUpdate.newLatLng(newPos));
        });
      }
    });
  }

  void _updateTrackedPolyline() {
    if (_trackedPath.length < 2) return;
    _polylines.removeWhere((p) => p.polylineId.value == 'rastro_recorrido');
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('rastro_recorrido'),
        points: List.from(_trackedPath),
        color: AppColors.primary.withOpacity(0.5),
        width: 5,
        patterns: [],
      ),
    );
  }

  Future<void> _loadRoutes() async {
    setState(() => _isLoading = true);
    try {
      final data = await _routeService.getRoutes();

      List<Map<String, dynamic>> clients = [];
      if (data.isNotEmpty) {
        final myRoute = data.first;
        final routeClients = List<Map<String, dynamic>>.from(
          myRoute['clients'] ?? [],
        );
        clients = activeRouteClients(routeClients);
      }
      if (mounted) {
        setState(() {
          _clients = clients;
          _isLoading = false;
        });
        _buildMarkers();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _buildMarkers() {
    _markers.clear();
    _polylines.clear();
    // Invalida las respuestas en vuelo de una lista de clientes anterior.
    _roadRouteVersion++;
    final List<LatLng> points = [];

    for (int i = 0; i < _clients.length; i++) {
      final c = _clients[i];
      final lat = double.tryParse(c['latitude']?.toString() ?? '');
      final lng = double.tryParse(c['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      final pos = LatLng(lat, lng);
      final empresa = c['business_name'] ?? '';
      final nombre = c['client_name1'] ?? '';
      points.add(pos);

      _markers.add(
        Marker(
          markerId: MarkerId('client_$i'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            (c['status'] == 'C')
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: empresa.isNotEmpty ? empresa : nombre,
            snippet: c['address'] ?? '',
          ),
          onTap: () => _focusClient(c),
        ),
      );
    }

    if (points.length > 1) {
      // Respaldo inmediato: línea recta entre los clientes en su orden.
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('mi_ruta'),
          points: points,
          color: AppColors.mapRoute,
          width: 3,
        ),
      );

      // Si estos mismos puntos ya se calcularon por vías, reutiliza el trazo
      // en lugar de pedirlo otra vez.
      final cached = _roadRoutePoints;
      if (cached != null &&
          _roadRouteSuccessSignature == _routeSignature(points)) {
        _polylines.removeWhere((p) => p.polylineId.value == 'mi_ruta');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('mi_ruta'),
            points: cached,
            color: AppColors.mapRoute,
            width: 3,
          ),
        );
        _hasRoadRoute = true;
      } else {
        _hasRoadRoute = false;
      }
    } else {
      _hasRoadRoute = false;
    }

    setState(() {});
    unawaited(_cargarRutaPorVias(points));
  }

  /// Reemplaza el trazo recto de 'mi_ruta' por la ruta real en carretera.
  ///
  /// Silencioso por diseño: si OSRM falla o no está disponible se conserva
  /// la línea recta como respaldo y solo se registra en `debugPrint`.
  Future<void> _cargarRutaPorVias(List<LatLng> points) async {
    final signature = _routeSignature(points);
    _latestRoadPoints = points;
    final now = DateTime.now();

    final shouldRequest = shouldRequestRoadRoute(
      pointCount: points.length,
      signature: signature,
      lastSuccessSignature: _roadRouteSuccessSignature,
      lastRequestAt: _roadRouteLastRequestAt,
      now: now,
    );

    // Sin puntos suficientes, ruta ya resuelta o demasiado pronto tras la
    // última petición: se conserva la línea recta como respaldo.
    if (!shouldRequest) return;

    // Una sola petición en vuelo: al terminar se reintenta si los puntos
    // cambiaron mientras tanto.
    if (_roadRouteRequestInFlight) return;

    // Se registra el instante de la petición (no el de éxito) para respetar
    // el intervalo mínimo entre llamadas al servidor público.
    _roadRouteLastRequestAt = now;
    _roadRouteRequestInFlight = true;
    final version = _roadRouteVersion;

    try {
      final road = await _routeService.getRoadRoute(
        points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      );

      if (!mounted) return;

      // Descarta respuestas viejas, salvo que los puntos sigan siendo los
      // mismos (por ejemplo tras un refresco sin cambios).
      final latestSignature = _latestRoadPoints == null
          ? null
          : _routeSignature(_latestRoadPoints!);
      if (version != _roadRouteVersion && latestSignature != signature) {
        return;
      }
      if (road.length < 2) return;

      final roadPoints = road
          .map((p) => LatLng(p['lat']!, p['lng']!))
          .toList(growable: false);

      // La firma de éxito solo se guarda con una ruta válida: un fallo no
      // impide reintentar con los mismos puntos en el siguiente refresco.
      _roadRouteSuccessSignature = signature;
      _roadRoutePoints = roadPoints;

      setState(() {
        // Nunca se pisa una ruta de navegación ya trazada.
        if (_polylines.any((p) => p.polylineId.value == 'ruta_navegacion')) {
          return;
        }
        _hasRoadRoute = true;
        _polylines.removeWhere((p) => p.polylineId.value == 'mi_ruta');
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('mi_ruta'),
            points: roadPoints,
            color: AppColors.mapRoute,
            width: 3,
          ),
        );
      });
    } on ApiException catch (e) {
      debugPrint('Ruta por vías no disponible: ${e.message}');
    } catch (e) {
      debugPrint('Ruta por vías no disponible: $e');
    } finally {
      _roadRouteRequestInFlight = false;
      // Solo se encadena una petición si los puntos cambiaron mientras
      // estaba en vuelo; la función pura aplica el intervalo mínimo.
      final latest = _latestRoadPoints;
      if (mounted && latest != null && _routeSignature(latest) != signature) {
        unawaited(_cargarRutaPorVias(latest));
      }
    }
  }

  /// Firma estable de una lista de puntos para no repetir peticiones.
  String _routeSignature(List<LatLng> points) => points
      .map(
        (p) =>
            '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}',
      )
      .join('|');

  void _focusClient(Map<String, dynamic> c) {
    final lat = double.tryParse(c['latitude']?.toString() ?? '');
    final lng = double.tryParse(c['longitude']?.toString() ?? '');
    if (lat == null || lng == null) return;
    _mapController.future.then((ctrl) {
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
    });
  }

  Future<void> _navegarACliente(Map<String, dynamic> c) async {
    final clientId = c['id_client']?.toString() ?? '';
    try {
      final nav = await _routeService.getClientNavigation(clientId);
      final destLat = double.tryParse(nav['latitude']?.toString() ?? '');
      final destLng = double.tryParse(nav['longitude']?.toString() ?? '');

      if (destLat == null || destLng == null) {
        _showMsg(
          'Este cliente no tiene coordenadas registradas',
          isError: true,
        );
        return;
      }
      if (_currentPosition == null) {
        _showMsg('No se pudo obtener tu ubicación actual', isError: true);
        return;
      }

      _showMsg('Trazando ruta...');

      final points = await _routeService.getDirections(
        originLat: _currentPosition!.latitude,
        originLng: _currentPosition!.longitude,
        destLat: destLat,
        destLng: destLng,
      );

      if (points.isEmpty) {
        _showMsg('No se pudo trazar la ruta', isError: true);
        return;
      }

      final routeLatLng = points
          .map((p) => LatLng(p['lat']!, p['lng']!))
          .toList();

      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value == 'ruta_navegacion');
        _polylines.removeWhere((p) => p.polylineId.value == 'mi_ruta');
        _hasRoadRoute = false;
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('ruta_navegacion'),
            points: routeLatLng,
            color: AppColors.primary,
            width: 4,
          ),
        );
        _markers.removeWhere((m) => m.markerId.value == 'destino_actual');
        _markers.add(
          Marker(
            markerId: const MarkerId('destino_actual'),
            position: LatLng(destLat, destLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(
              title: _clientName(c),
              snippet: c['address'] ?? '',
            ),
          ),
        );
      });

      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(_getBounds(routeLatLng), 60),
      );

      _showMsg('Ruta trazada — ${_clientName(c)}');
    } on ApiException catch (e) {
      _showMsg(e.message, isError: true);
    } catch (_) {
      _showMsg('Error al trazar la ruta', isError: true);
    }
  }

  LatLngBounds _getBounds(List<LatLng> points) {
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
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? AppColors.statusError
            : AppColors.statusSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _clientName(Map<String, dynamic> c) {
    final empresa = c['business_name'] ?? '';
    final nombre = c['client_name1'] ?? '';
    return empresa.isNotEmpty ? empresa : nombre;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context); // ← agregado

    return Scaffold(
      backgroundColor: cs.background,
      bottomNavigationBar: const RoleBottomNav(currentRoute: AppRoutes.route),
      body: Column(
        children: [
          // ── AppBar
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mi ruta de hoy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _hasGpsFix
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _hasGpsFix
                                      ? const Color(0xFFA5D6A7)
                                      : Colors.white.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _hasGpsFix ? 'GPS activo' : 'Sin GPS',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            _trackedPath.clear();
                            _polylines.removeWhere(
                              (p) => p.polylineId.value == 'rastro_recorrido',
                            );
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.layers_clear,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_clients.length} paradas',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target:
                          _currentPosition ?? const LatLng(8.2340, -73.2648),
                      zoom: 13,
                    ),
                    onMapCreated: (ctrl) => _mapController.complete(ctrl),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                ),

                // ── Atribución exigida por OSRM/OpenStreetMap
                if (_hasRoadRoute)
                  Positioned(
                    left: 10,
                    top: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.card.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cs.border),
                        ),
                        child: Text(
                          'Rutas © OpenStreetMap · OSRM',
                          style: TextStyle(fontSize: 10, color: cs.textHint),
                        ),
                      ),
                    ),
                  ),

                // ── Panel deslizable
                DraggableScrollableSheet(
                  initialChildSize: _panelInitial,
                  minChildSize: _panelMin,
                  maxChildSize: _panelMax,
                  snap: true,
                  snapSizes: const [_panelMin, _panelInitial, _panelMax],
                  builder: (context, scrollCtrl) {
                    return Container(
                      decoration: BoxDecoration(
                        color: cs.card, // ← cambiado
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 12,
                            offset: Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SingleChildScrollView(
                            controller: scrollCtrl,
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 10,
                                    bottom: 4,
                                  ),
                                  child: Container(
                                    width: 38,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: cs.border, // ← cambiado
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    6,
                                    16,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.map_outlined,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${_clients.length} clientes asignados en tu ruta',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: cs.textPrimary,
                                          ), // ← cambiado
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: cs.border,
                                ), // ← cambiado
                              ],
                            ),
                          ),

                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  )
                                : _clients.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.map_outlined,
                                          size: 52,
                                          color: cs.textHint.withOpacity(0.4),
                                        ), // ← cambiado
                                        const SizedBox(height: 12),
                                        Text(
                                          'No tienes clientes asignados hoy',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: cs.textHint,
                                          ),
                                        ), // ← cambiado
                                        const SizedBox(height: 6),
                                        Text(
                                          'El administrador asignará tu ruta',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cs.textHint.withOpacity(0.6),
                                          ),
                                        ), // ← cambiado
                                      ],
                                    ),
                                  )
                                : RefreshIndicator(
                                    color: AppColors.primary,
                                    onRefresh: _loadRoutes,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        8,
                                        14,
                                        14,
                                      ),
                                      itemCount: _clients.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (_, i) {
                                        final c = _clients[i];
                                        return GestureDetector(
                                          onTap: () => _focusClient(c),
                                          child: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: cs.card, // ← cambiado
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: cs.border,
                                              ), // ← cambiado
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withOpacity(0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${i + 1}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        _clientName(c),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: cs.textPrimary,
                                                        ),
                                                      ), // ← cambiado
                                                      Text(
                                                        c['address'] ?? '',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: cs.textHint,
                                                        ),
                                                      ), // ← cambiado
                                                    ],
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _navegarACliente(c),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Row(
                                                      children: [
                                                        Icon(
                                                          Icons.navigation,
                                                          color: Colors.white,
                                                          size: 14,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Ir',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
