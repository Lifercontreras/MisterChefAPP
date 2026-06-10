import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../services/customer_service.dart';
import '../orders/new_order_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _customerService = CustomerService();

  Map<String, dynamic>? _client;
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = await _customerService.getClientById(widget.customerId);
      List<Map<String, dynamic>> invoices = [];
      if (client['invoices'] != null) {
        invoices = List<Map<String, dynamic>>.from(client['invoices'])
            .take(5)
            .toList();
      }
      if (mounted) {
        setState(() {
          _client    = client;
          _invoices  = invoices;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _initials {
    final parts = widget.customerName.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  int    get _totalPedidos => _invoices.length;
  double get _totalCompras => _invoices.fold(
      0, (sum, inv) => sum + (inv['total'] ?? 0).toDouble());

  String _formatMoneda(double valor) {
    if (valor >= 1000000) return '\$${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000)    return '\$${(valor / 1000).toStringAsFixed(0)}K';
    return '\$${valor.toStringAsFixed(0)}';
  }

  String _formatTiempo(String? fecha) {
    if (fecha == null) return 'N/A';
    final dt = DateTime.tryParse(fecha);
    if (dt == null) return 'N/A';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays}d';
  }

  String _statusLabel(String? status) {
    switch (status) {
      case AppConstants.invoicePending:   return 'Pendiente';
      case AppConstants.invoiceConfirmed: return 'Confirmada';
      case AppConstants.invoiceCancelled: return 'Anulada';
      default: return '—';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case AppConstants.invoicePending:   return AppColors.statusWarning;
      case AppConstants.invoiceConfirmed: return AppColors.statusSuccess;
      case AppConstants.invoiceCancelled: return AppColors.statusError;
      default: return AppColors.textHintLight;
    }
  }

  Future<void> _llamar() async {
    final tel = _client?['phone_number']?.toString() ?? '';
    if (tel.isEmpty) {
      _showMsg('No hay teléfono registrado', isError: true);
      return;
    }
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _abrirMapa() async {
    final lat = (_client?['latitude']  as num?)?.toDouble();
    final lng = (_client?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      _showMsg('No hay coordenadas registradas', isError: true);
      return;
    }
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _toggleStatus() async {
    final active = _client?['status'] == true;
    final id = widget.customerId;
    try {
      await _customerService.changeClientStatus(id, !active);
      _showMsg(active ? 'Cliente desactivado' : 'Cliente activado');
      await _loadData();
    } catch (_) {
      _showMsg('Error al cambiar el estado.', isError: true);
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? AppColors.statusError : AppColors.statusSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final active    = _client?['status'] == true;
    final ciudad    = _client?['city']?['city_name'] ?? '';
    final depto     = _client?['city']?['department']?['department_name'] ?? '';
    final ubicacion = [ciudad, depto].where((s) => s.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.primary))
          : Column(
              children: [
                _buildHeader(active),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStats(),
                          const SizedBox(height: 14),
                          _buildSectionLabel('Información de contacto'),
                          const SizedBox(height: 8),
                          _buildContactCard(ubicacion),
                          const SizedBox(height: 14),
                          _buildQuickActions(),
                          const SizedBox(height: 14),
                          if (_invoices.isNotEmpty) ...[
                            _buildSectionLabel('Últimas facturas'),
                            const SizedBox(height: 8),
                            _buildInvoiceList(),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildCreateButton(),
              ],
            ),
    );
  }

  Widget _buildHeader(bool active) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -50, right: -40,
              child: Container(
                width: 140, height: 140,
                decoration: const BoxDecoration(
                    color: AppColors.primaryDark, shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Detalle del cliente',
                          style: TextStyle(fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 3),
                        ),
                        child: Center(
                          child: Text(_initials,
                              style: const TextStyle(fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimaryLight)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.customerName,
                                style: const TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(_client?['address'] ?? 'Sin dirección',
                                style: TextStyle(fontSize: 11,
                                    color: Colors.white.withOpacity(0.7))),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? const Color(0xFFA5D6A7)
                                        : const Color(0xFFEF9A9A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  active
                                      ? 'Cliente activo'
                                      : 'Cliente inactivo',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final lastDate = _invoices.isNotEmpty
        ? _formatTiempo(_invoices.first['date']?.toString())
        : 'N/A';
    final stats = [
      {'num': '$_totalPedidos',             'lbl': 'Facturas'},
      {'num': _formatMoneda(_totalCompras), 'lbl': 'Total compras'},
      {'num': lastDate,                      'lbl': 'Últ. factura'},
    ];
    return Row(
      children: stats.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Text(s['num']!,
                    style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary)),
                const SizedBox(height: 3),
                Text(s['lbl']!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9,
                        color: AppColors.textHintLight)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContactCard(String ubicacion) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _ContactRow(
              icon: Icons.phone_outlined,
              label: 'Teléfono',
              value: _client?['phone_number']?.toString() ?? 'No registrado'),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _ContactRow(
              icon: Icons.location_on_outlined,
              label: 'Dirección',
              value: _client?['address'] ?? 'No registrada'),
          if (ubicacion.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            _ContactRow(
                icon: Icons.location_city_outlined,
                label: 'Ciudad',
                value: ubicacion),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final active = _client?['status'] == true || _client?['status'] == 1;
    return Row(
      children: [
        Expanded(
          child: _ActionBtn(
            icon: Icons.map_outlined,
            label: 'Ver mapa',
            color: AppColors.statusSuccess,
            bgColor: AppColors.chipSuccessBg,
            onTap: _abrirMapa,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            icon: Icons.navigation_outlined,
            label: 'Navegar',
            color: AppColors.statusWarning,
            bgColor: AppColors.chipWarningBg,
            onTap: () => Navigator.pushNamed(context, '/route'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionBtn(
            icon: active ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
            label: active ? 'Desactivar' : 'Activar',
            color: active ? AppColors.statusError : AppColors.statusSuccess,
            bgColor: active ? AppColors.chipErrorBg : AppColors.chipSuccessBg,
            onTap: _toggleStatus,
          ),
        ),
      ],
    );
  }


  Widget _buildInvoiceList() {
    return Column(
      children: _invoices.map((inv) {
        final status = inv['status'] ?? '';
        final total  = (inv['total'] ?? 0).toDouble();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: _statusColor(status),
                      shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${inv['id_invoice'] ?? '---'}',
                        style: const TextStyle(fontSize: 10,
                            color: AppColors.textHintLight)),
                    Text(
                      '${_formatTiempo(inv['date']?.toString())} · ${_statusLabel(status)}',
                      style: const TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimaryLight),
                    ),
                  ],
                ),
              ),
              Text(_formatMoneda(total),
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewOrderScreen(preselectedCustomer: _client),
            ),
          ),
          icon: const Icon(Icons.receipt_long_outlined, size: 20),
          label: const Text('Crear factura a este cliente'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) => Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: AppColors.textSecondaryLight, letterSpacing: 1.2));
}

// ── Fila de contacto
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ContactRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.chipErrorBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10,
                    color: AppColors.textHintLight)),
                Text(value, style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botón de acción rápida
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bgColor;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
      required this.color, required this.bgColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}