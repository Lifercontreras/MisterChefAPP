import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../services/route_service.dart';
import '../../widgets/role_bottom_nav.dart';

class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({super.key});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final _routeService = RouteService();

  final Set<Marker> _markers = {};
  List<Map<String, dynamic>> _domiciliarios = [];
  bool _isLoading = true;

  // ── Colores para distinguir cada domiciliario en el mapa
  final List<double> _markerHues = [
    BitmapDescriptor.hueRed,
    BitmapDescriptor.hueBlue,
    BitmapDescriptor.hueGreen,
    BitmapDescriptor.hueViolet,
    BitmapDescriptor.hueOrange,
    BitmapDescriptor.hueCyan,
    BitmapDescriptor.hueYellow,
    BitmapDescriptor.hueRose,
  ];

  // ── Refresco automático cada 30 segundos
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadLocations();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── GET /api/v1/location
  Future<void> _loadLocations() async {
    try {
      final data = await _routeService.getActiveLocations();
      if (mounted) {
        setState(() {
          _domiciliarios = data;
          _isLoading     = false;
        });
        _buildMarkers();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _buildMarkers() {
    _markers.clear();

    for (int i = 0; i < _domiciliarios.length; i++) {
      final d   = _domiciliarios[i];
      final lat = double.tryParse(d['latitude'].toString());
      final lng = double.tryParse(d['longitude'].toString());
      if (lat == null || lng == null) continue;

      final hue  = _markerHues[i % _markerHues.length];
      final name = d['name'] ?? 'Domiciliario';

      _markers.add(
        Marker(
          markerId: MarkerId(d['document_employee'].toString()),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: name,
            snippet: _formatLastUpdate(d['last_update']),
          ),
        ),
      );
    }

    setState(() {});
  }

  String _formatLastUpdate(String? lastUpdate) {
    if (lastUpdate == null) return 'Sin actualización';
    final dt = DateTime.tryParse(lastUpdate);
    if (dt == null) return 'Sin actualización';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Hace ${diff.inHours}h';
    return 'Hace ${diff.inDays}d';
  }

  // ── Centrar mapa en un domiciliario al tocar su tarjeta
  Future<void> _focusOnDelivery(Map<String, dynamic> d) async {
    final lat = double.tryParse(d['latitude'].toString());
    final lng = double.tryParse(d['longitude'].toString());
    if (lat == null || lng == null) return;

    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
    );
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppColors.statusError : AppColors.statusSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Color _dotColor(int index) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.cyan,
      Colors.amber,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      bottomNavigationBar: const RoleBottomNav(currentRoute: AppRoutes.home),
      body: Column(
        children: [
          // ── App Bar
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Domiciliarios en mapa',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white),
                        ),
                      ],
                    ),
                    // Botón refrescar manualmente
                    GestureDetector(
                      onTap: () {
                        setState(() => _isLoading = true);
                        _loadLocations();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.refresh,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${_domiciliarios.length} activos',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Google Maps
          SizedBox(
            height: 300,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(8.2340, -73.2648), // Ocaña por defecto
                zoom: 12,
              ),
              onMapCreated: (controller) =>
                  _mapController.complete(controller),
              markers: _markers,
              myLocationEnabled:       false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled:     true,
              mapToolbarEnabled:       false,
            ),
          ),

          // ── Subtítulo
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 10),
                const SizedBox(width: 6),
                Text(
                  'Actualización automática cada 30 segundos',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHintLight.withOpacity(0.8)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // ── Lista de domiciliarios activos
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _domiciliarios.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off_outlined,
                                size: 52,
                                color: AppColors.textHintLight
                                    .withOpacity(0.4)),
                            const SizedBox(height: 12),
                            const Text('No hay domiciliarios activos',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textHintLight)),
                            const SizedBox(height: 6),
                            Text(
                              'Los domiciliarios aparecerán aquí cuando inicien su jornada',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHintLight
                                      .withOpacity(0.6)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadLocations,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _domiciliarios.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final d    = _domiciliarios[i];
                            final name = d['name'] ?? 'Domiciliario';
                            final last = _formatLastUpdate(
                                d['last_update']);

                            return GestureDetector(
                              onTap: () => _focusOnDelivery(d),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.borderLight),
                                ),
                                child: Row(
                                  children: [
                                    // Indicador de color del marcador
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: _dotColor(i)
                                            .withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                            Icons.delivery_dining,
                                            color: _dotColor(i),
                                            size: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(name,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                  color: AppColors
                                                      .textPrimaryLight)),
                                          Text(
                                            'Doc: ${d['document_employee'] ?? ''}',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors
                                                    .textHintLight),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Última actualización + flecha
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.chipSuccessBg,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text('Activo',
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                  color: AppColors
                                                      .statusSuccess)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(last,
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: AppColors
                                                    .textHintLight)),
                                      ],
                                    ),

                                    const SizedBox(width: 6),
                                    const Icon(Icons.my_location,
                                        color: AppColors.primary, size: 18),
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
  }
}