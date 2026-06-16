import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../config/constants.dart';
import '../../services/order_service.dart';
import '../../widgets/role_bottom_nav.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _searchCtrl   = TextEditingController();
  final _orderService = OrderService();

  int _filterIndex = 0;
  List<Map<String, dynamic>> _allOrders      = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;

  final _statusMap = {
    1: AppConstants.invoicePending,
    2: AppConstants.invoiceConfirmed,
    3: AppConstants.invoiceCancelled,
  };

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await _orderService.getInvoices();
      if (mounted) {
        setState(() {
          _allOrders = data;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    List<Map<String, dynamic>> result = _allOrders.where((inv) {
      final c       = inv['client'];
      final empresa = (c?['business_name']     ?? '').toLowerCase();
      final nombre  = '${c?['client_name1'] ?? ''} ${c?['client_last_name1'] ?? ''}'.toLowerCase();
      final id      = (inv['id_invoice'] ?? '').toString().toLowerCase();
      return empresa.contains(q) || nombre.contains(q) || id.contains(q);
    }).toList();

    if (_filterIndex > 0) {
      final status = _statusMap[_filterIndex];
      result = result.where((o) => o['status'] == status).toList();
    }
    setState(() => _filteredOrders = result);
  }

  String _formatMoneda(dynamic valor) {
    final v = double.tryParse((valor ?? 0).toString()) ?? 0.0;
    return '\$${v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _formatTiempo(String? fecha) {
    if (fecha == null) return '';
    final dt = DateTime.tryParse(fecha);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1)    return 'Ayer';
    return 'Hace ${diff.inDays} días';
  }

  String _clientName(Map<String, dynamic> inv) {
    final c = inv['client'];
    if (c == null) return 'Cliente desconocido';
    final empresa  = c['business_name']     ?? '';
    final nombre   = c['client_name1']      ?? '';
    final apellido = c['client_last_name1'] ?? '';
    return empresa.isNotEmpty ? empresa : '$nombre $apellido'.trim();
  }

  int _countProducts(Map<String, dynamic> inv) {
    final details = inv['details'];
    if (details == null) return 0;
    return (details as List).length;
  }

  Widget _buildBadge(String? status) {
    final isDark = AppColorScheme.of(context).isDark;
    String label; Color bg, fg;

    switch (status) {
      case AppConstants.invoicePending:
        label = 'Pendiente';
        fg    = AppColors.statusWarning;
        bg    = isDark
            ? AppColors.statusWarning.withOpacity(0.15)
            : AppColors.chipWarningBg;
        break;
      case AppConstants.invoiceConfirmed:
        label = 'Confirmada';
        fg    = AppColors.statusSuccess;
        bg    = isDark
            ? AppColors.statusSuccess.withOpacity(0.15)
            : AppColors.chipSuccessBg;
        break;
      case AppConstants.invoiceCancelled:
        label = 'Anulada';
        fg    = AppColors.statusError;
        bg    = isDark
            ? AppColors.statusError.withOpacity(0.15)
            : AppColors.chipErrorBg;
        break;
      default:
        label = 'Desconocido';
        fg    = AppColorScheme.of(context).textHint;
        bg    = AppColorScheme.of(context).border;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)), // ← borde sutil
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10,
              fontWeight: FontWeight.w600, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs   = AppColorScheme.of(context);
    final tabs = ['Todos', 'Pendientes', 'Confirmadas', 'Anuladas'];

    return Scaffold(
      backgroundColor: cs.background,
      bottomNavigationBar: const RoleBottomNav(currentRoute: AppRoutes.orders),
      body: Column(
        children: [
          // ── AppBar
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: const Text('Mis pedidos',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar pedido o cliente...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.6)
                                : Colors.black54,
                          ),
                          prefixIcon: Icon(Icons.search,
                              color: Colors.white.withOpacity(0.7), size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tabs
          Container(
            color: cs.card,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final isActive = _filterIndex == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _filterIndex = i);
                      _applyFilter();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8, bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : cs.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(tabs[i],
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isActive ? Colors.white : cs.textHint)),
                    ),
                  );
                }),
              ),
            ),
          ),

          Divider(height: 1, color: cs.border),

          // ── Lista
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: AppColors.primary))
                : _filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 52,
                                color: cs.textHint.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text('No hay pedidos',
                                style: TextStyle(fontSize: 14,
                                    color: cs.textHint)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadOrders,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filteredOrders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final inv   = _filteredOrders[i];
                            final nProd = _countProducts(inv);
                            return GestureDetector(
                              onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(
                                    orderId: inv['id_invoice'].toString()),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('#${inv['id_invoice'] ?? '---'}',
                                            style: TextStyle(fontSize: 11,
                                                color: cs.textHint)),
                                        _buildBadge(inv['status']),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(_clientName(inv),
                                        style: TextStyle(fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: cs.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatTiempo(inv['date']?.toString())} · $nProd producto${nProd != 1 ? 's' : ''}',
                                      style: TextStyle(fontSize: 11,
                                          color: cs.textHint),
                                    ),
                                    Divider(height: 18, color: cs.divider),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatMoneda(inv['total']),
                                            style: const TextStyle(fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.primary)),
                                        Icon(Icons.chevron_right,
                                            color: cs.border, size: 20),
                                      ],
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NewOrderScreen()));
          _loadOrders();
        },
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}