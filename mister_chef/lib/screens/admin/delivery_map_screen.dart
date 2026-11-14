import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/client_map_logic.dart';
import '../../config/constants.dart';
import '../../config/location_polling_logic.dart';
import '../../services/api_service.dart';
import '../../services/customer_service.dart';
import '../../services/employee_service.dart';
import '../../services/route_service.dart';
import '../../widgets/role_bottom_nav.dart';

class DeliveryMapScreen extends StatefulWidget {
  const DeliveryMapScreen({super.key});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen>
    with WidgetsBindingObserver {
  final Completer<GoogleMapController> _mapController = Completer();
  final _routeService = RouteService();
  final _customerService = CustomerService();
  final _employeeService = EmployeeService();

  final Set<Marker> _markers = {};
  List<Map<String, dynamic>> _domiciliarios = [];
  List<Map<String, dynamic>> _clientes = [];
  List<String> _sellerDocuments = [];
  final Map<String, String> _sellerNames = {};
  bool _isLoading = true;

  // ── Visibilidad y filtro de clientes (se aplican en el dispositivo)
  bool _showClients = true;
  String _sellerFilter = sellerFilterAll;

  // ── Estado del último refresco
  String? _errorMessage;
  String? _clientsErrorMessage;
  DateTime? _lastSuccessfulRefresh;

  // ── Caché de íconos circulares por color
  final Map<int, BitmapDescriptor> _clientIconCache = {};

  // ── Evita que una construcción antigua de marcadores pise a una nueva
  int _markersGeneration = 0;

  // ── Refresco automático de ubicaciones (solo GET /location)
  Timer? _refreshTimer;
  bool _locationsRequestInFlight = false;
  bool _appPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocations();
    _loadClients();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoRefresh();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appPaused = false;
      _refreshLocationsIfIdle();
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _appPaused = true;
      _stopAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _stopAutoRefresh();
    _refreshTimer = Timer.periodic(
      AppConstants.locationUpdateInterval,
      (_) => _refreshLocationsIfIdle(),
    );
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Refresca solo las ubicaciones si no hay una petición en vuelo y la app
  /// está visible. Los clientes nunca entran al polling automático.
  void _refreshLocationsIfIdle() {
    if (!shouldRunLocationPoll(
      requestInFlight: _locationsRequestInFlight,
      appPaused: _appPaused,
    )) {
      return;
    }
    _loadLocations();
  }

  // ── GET /api/v1/location
  Future<void> _loadLocations() async {
    // No solapa peticiones: si la anterior sigue en vuelo, se espera al
    // siguiente ciclo (o al siguiente refresco manual).
    if (_locationsRequestInFlight) return;
    _locationsRequestInFlight = true;
    try {
      await _fetchLocations();
    } finally {
      _locationsRequestInFlight = false;
    }
  }

  Future<void> _fetchLocations() async {
    try {
      final data = await _routeService.getActiveLocations();
      if (!mounted) return;
      setState(() {
        _domiciliarios = data;
        _isLoading = false;
        _errorMessage = null;
        _lastSuccessfulRefresh = DateTime.now();
      });
      await _buildMarkers();
    } on ApiException catch (e) {
      // Conserva los marcadores y la lista anteriores.
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudieron cargar las ubicaciones.';
      });
    }
  }

  // ── GET /api/v1/clients/map + GET /api/v1/employees
  Future<void> _loadClients() async {
    List<Map<String, dynamic>> clients = [];
    String? clientsError;

    try {
      clients = await _customerService.getClientsMap();
    } on ApiException catch (e) {
      clientsError = e.message;
    } catch (_) {
      clientsError = 'No se pudieron cargar los clientes.';
    }

    // Lista estable de vendedores: se ordena por documento para que el color
    // de cada uno no dependa de qué domiciliarios estén conectados.
    final sellers = <String, String>{};
    var employeesLoaded = false;
    try {
      final employees = await _employeeService.getEmployees();
      for (final employee in employees) {
        if (employee['type']?.toString() != AppConstants.roleVendedor) {
          continue;
        }
        final document = normalizeDocument(employee['document_employee']);
        if (document == null) continue;
        sellers[document] = _employeeFullName(employee);
      }
      employeesLoaded = true;
    } catch (_) {
      // Si /employees falla, se conserva la lista de vendedores anterior.
    }

    // Completa vendedores que solo aparezcan en el payload de clientes.
    final clientsForSellers = clientsError == null ? clients : _clientes;
    for (final client in clientsForSellers) {
      final document = normalizeDocument(client['document_employee']);
      if (document == null || sellers.containsKey(document)) continue;
      final name = client['seller_name']?.toString().trim() ?? '';
      sellers[document] = name.isEmpty ? 'Vendedor $document' : name;
    }

    final sellerDocuments = buildSortedSellerDocuments(sellers.keys);

    if (!mounted) return;
    setState(() {
      // Si falló la carga de clientes se conservan los marcadores anteriores
      // y solo se muestra el error en el banner existente.
      if (clientsError == null) {
        _clientes = clients;
        _clientsErrorMessage = null;
      } else {
        _clientsErrorMessage = clientsError;
      }

      if (clientsError == null || employeesLoaded) {
        _sellerNames
          ..clear()
          ..addAll(sellers);
        _sellerDocuments = sellerDocuments;
        // Si el vendedor seleccionado ya no existe, vuelve a "Todos".
        if (_sellerFilter != sellerFilterAll &&
            _sellerFilter != sellerFilterUnassigned &&
            !_sellerDocuments.contains(_sellerFilter)) {
          _sellerFilter = sellerFilterAll;
        }
      }
    });
    await _buildMarkers();
  }

  String _employeeFullName(Map<String, dynamic> employee) {
    final parts = <String>[
      employee['name_1']?.toString().trim() ?? '',
      employee['last_name_1']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty);

    if (parts.isEmpty) {
      return 'Vendedor ${employee['document_employee']}';
    }
    return parts.join(' ');
  }

  /// Clientes que pasan el filtro actual, independientemente de si el
  /// interruptor está encendido (el conteo se muestra siempre).
  List<Map<String, dynamic>> get _filteredClients => _clientes
      .where((client) => clientMatchesSellerFilter(client, _sellerFilter))
      .toList();

  List<DropdownMenuItem<String>> _sellerFilterItems() {
    return [
      const DropdownMenuItem(
        value: sellerFilterAll,
        child: Text('Todos los vendedores'),
      ),
      for (final document in _sellerDocuments)
        DropdownMenuItem(
          value: document,
          child: Text(
            _sellerNames[document] ?? 'Vendedor $document',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      const DropdownMenuItem(
        value: sellerFilterUnassigned,
        child: Text('Sin asignar'),
      ),
    ];
  }

  Future<void> _buildMarkers() async {
    final generation = ++_markersGeneration;
    final domiciliarios = List<Map<String, dynamic>>.from(_domiciliarios);
    final clients = _showClients
        ? _filteredClients
        : <Map<String, dynamic>>[];
    final sellerDocuments = List<String>.from(_sellerDocuments);
    final markers = <Marker>{};

    // ── Pines de domiciliarios activos (GET /location)
    for (final d in domiciliarios) {
      final lat = double.tryParse(d['latitude'].toString());
      final lng = double.tryParse(d['longitude'].toString());
      if (lat == null || lng == null) continue;

      final colorIndex = sellerColorIndex(
        d['document_employee'],
        sellerDocuments,
      );
      // Si el documento no está en la lista de vendedores, usa el primer hue
      // como respaldo (los clientes sin vendedor sí usan gris).
      final hue = colorIndex < 0
          ? ClientMapPalette.hues.first
          : ClientMapPalette.hues[colorIndex];

      markers.add(
        Marker(
          markerId: MarkerId(d['document_employee'].toString()),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          zIndexInt: 1,
          infoWindow: InfoWindow(
            title: d['name'] ?? 'Domiciliario',
            snippet: _timeAgo(d['last_update']) ?? '',
          ),
        ),
      );
    }

    // ── Marcadores de clientes (GET /clients/map)
    for (final client in clients) {
      final lat = double.tryParse(client['latitude']?.toString() ?? '');
      final lng = double.tryParse(client['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;

      final color = clientMarkerColor(
        client['document_employee'],
        sellerDocuments,
      );
      final icon = await _clientMarkerIcon(color);
      if (!mounted || generation != _markersGeneration) return;

      markers.add(
        Marker(
          markerId: MarkerId('client_${client['id_client']}'),
          position: LatLng(lat, lng),
          icon: icon,
          zIndexInt: 2, // Por encima de los pines de domiciliarios
          infoWindow: InfoWindow(title: clientBusinessName(client)),
          onTap: () => _showClientDetails(client),
        ),
      );
    }

    if (!mounted || generation != _markersGeneration) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
    });
  }

  /// Dibuja un círculo del color del vendedor, con borde blanco, y lo cachea
  /// por color para no regenerar el bitmap en cada refresco.
  Future<BitmapDescriptor> _clientMarkerIcon(Color color) async {
    final cacheKey = color.toARGB32();
    final cached = _clientIconCache[cacheKey];
    if (cached != null) return cached;

    const size = 40.0;
    const center = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawCircle(
      center,
      18,
      ui.Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawCircle(center, 14, ui.Paint()..color = color);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();

    if (data == null) {
      return BitmapDescriptor.defaultMarkerWithHue(
        ClientMapPalette.hues.first,
      );
    }

    final icon = BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      width: size,
      height: size,
    );
    _clientIconCache[cacheKey] = icon;
    return icon;
  }

  /// Devuelve "hace X min" a partir de `last_update`, o `null` si el valor
  /// no puede parsearse (así no se inventa una hora de actualización).
  String? _timeAgo(dynamic lastUpdate) {
    if (lastUpdate == null) return null;
    final dt = DateTime.tryParse(lastUpdate.toString());
    if (dt == null) return null;
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inMinutes < 1) return 'hace menos de 1 min';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  /// Hora local en formato HH:mm para el banner de error.
  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Banner visible con el error y la hora del último refresco exitoso.
  Widget _buildErrorBanner(String message) {
    final last = _lastSuccessfulRefresh;
    final lastText = last == null
        ? 'Aún no hay un refresco exitoso'
        : 'Última actualización exitosa: ${_formatTime(last)}';

    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Error al actualizar el mapa: $message. $lastText',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          color: AppColors.chipErrorBg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off,
                color: AppColors.statusError,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.statusError,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastText,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Centrar mapa en un domiciliario al tocar su tarjeta
  Future<void> _focusOnDelivery(Map<String, dynamic> d) async {
    final lat = double.tryParse(d['latitude'].toString());
    final lng = double.tryParse(d['longitude'].toString());
    if (lat == null || lng == null) return;

    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16));
  }

  Color _dotColor(dynamic document) {
    final index = sellerColorIndex(document, _sellerDocuments);
    return index < 0
        ? ClientMapPalette.unassigned
        : ClientMapPalette.colors[index];
  }

  // ── Bottom sheet con los datos del cliente tocado en el mapa
  void _showClientDetails(Map<String, dynamic> client) {
    final seller = client['seller_name']?.toString().trim() ?? '';
    final sellerName = seller.isEmpty ? 'Sin asignar' : seller;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicador de arrastre del modal.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _dotColor(
                        client['document_employee'],
                      ).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storefront_outlined,
                      color: _dotColor(client['document_employee']),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      clientBusinessName(client),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    _detailRow(
                      Icons.location_on_outlined,
                      'Dirección',
                      _displayValue(client['address']),
                    ),
                    const Divider(height: 1, color: AppColors.borderLight),
                    _detailRow(
                      Icons.phone_outlined,
                      'Teléfono',
                      _displayValue(client['phone_number']),
                    ),
                    const Divider(height: 1, color: AppColors.borderLight),
                    _detailRow(
                      Icons.person_outline,
                      'Vendedor asignado',
                      sellerName,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textHintLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textHintLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra "—" cuando el backend devuelve un campo vacío o nulo.
  String _displayValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _clientsErrorMessage ?? _errorMessage;

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
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
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
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    // Botón refrescar manualmente
                    GestureDetector(
                      onTap: () {
                        setState(() => _isLoading = true);
                        _loadLocations();
                        _loadClients();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_domiciliarios.length} activos',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
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

          // ── Banner de error (se oculta cuando el refresco vuelve a funcionar)
          if (errorMessage != null) _buildErrorBanner(errorMessage),

          // ── Google Maps
          SizedBox(
            height: 300,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(8.2340, -73.2648), // Ocaña por defecto
                zoom: 12,
              ),
              onMapCreated: (controller) => _mapController.complete(controller),
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),

          // ── Controles de clientes + subtítulo
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle, color: Colors.green, size: 10),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Actualización automática cada ${AppConstants.locationUpdateInterval.inSeconds} segundos',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textHintLight.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    Text(
                      '${_filteredClients.length} clientes',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      color: AppColors.textHintLight,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Mostrar clientes',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    Switch(
                      value: _showClients,
                      onChanged: (value) {
                        setState(() => _showClients = value);
                        _buildMarkers();
                      },
                    ),
                  ],
                ),
                if (_showClients)
                  Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_outlined,
                        color: AppColors.textHintLight,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sellerFilter,
                            isExpanded: true,
                            isDense: true,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimaryLight,
                            ),
                            items: _sellerFilterItems(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _sellerFilter = value);
                              _buildMarkers();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // ── Lista de domiciliarios activos
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _domiciliarios.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          size: 52,
                          color: AppColors.textHintLight.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay domiciliarios activos',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textHintLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Los domiciliarios aparecerán aquí cuando inicien su jornada',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHintLight.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      await Future.wait([
                        _loadLocations(),
                        _loadClients(),
                      ]);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: _domiciliarios.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final d = _domiciliarios[i];
                        final name = d['name'] ?? 'Domiciliario';
                        final timeAgo = _timeAgo(d['last_update']);

                        return GestureDetector(
                          onTap: () => _focusOnDelivery(d),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Row(
                              children: [
                                // Indicador de color del marcador
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _dotColor(
                                      d['document_employee'],
                                    ).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.delivery_dining,
                                      color: _dotColor(
                                        d['document_employee'],
                                      ),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      Text(
                                        'Doc: ${d['document_employee'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textHintLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Última actualización + flecha
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (timeAgo != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.chipSuccessBg,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          timeAgo,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.statusSuccess,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.my_location,
                                  color: AppColors.primary,
                                  size: 18,
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
  }
}
