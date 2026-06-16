import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../services/customer_service.dart';
import '../../widgets/role_bottom_nav.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchCtrl      = TextEditingController();
  final _customerService = CustomerService();

  List<Map<String, dynamic>> _allCustomers      = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _customerService.getClients();
      if (mounted) {
        setState(() {
          _allCustomers = data;
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
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        final empresa = (c['business_name']     ?? '').toLowerCase();
        final nombre  = '${c['client_name1'] ?? ''} ${c['client_last_name1'] ?? ''}'.toLowerCase();
        final dir     = (c['address'] ?? '').toLowerCase();
        return empresa.contains(q) || nombre.contains(q) || dir.contains(q);
      }).toList();
    });
  }

  String _displayName(Map<String, dynamic> c) {
    final empresa  = c['business_name']     ?? '';
    final nombre   = c['client_name1']      ?? '';
    final apellido = c['client_last_name1'] ?? '';
    return empresa.isNotEmpty ? empresa : '$nombre $apellido'.trim();
  }

  String _initials(Map<String, dynamic> c) {
    final name  = _displayName(c);
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color _avatarColor(int index) {
    final colors = [
      AppColors.primary,
      AppColors.primaryDark,
      AppColors.statusInfo,
      AppColors.statusWarning,
      AppColors.statusSuccess,
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);

    return Scaffold(
      backgroundColor: cs.background,
      bottomNavigationBar: const RoleBottomNav(currentRoute: AppRoutes.customers),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () async {
          final result = await Navigator.pushNamed(context, AppRoutes.createCustomer);
          if (result == true) _loadCustomers();
        },
        child: const Icon(Icons.add, size: 28),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Clientes',
                            style: TextStyle(fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${_filteredCustomers.length} clientes',
                              style: const TextStyle(fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
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
                          hintText: 'Buscar por nombre o dirección...',
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

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(
                    color: AppColors.primary))
                : _filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 52,
                                color: cs.textHint.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text('No se encontraron clientes',
                                style: TextStyle(fontSize: 14,
                                    color: cs.textHint)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _loadCustomers,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filteredCustomers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c      = _filteredCustomers[i];
                            final nombre = _displayName(c);
                            final dir    = c['address'] ?? 'Sin dirección';
                            final active = c['status'] == true || c['status'] == 1;
                            final ciudad = c['city']?['city_name'] ?? '';

                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerDetailScreen(
                                    customerId:   c['id_client'].toString(),
                                    customerName: nombre,
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cs.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46, height: 46,
                                      decoration: BoxDecoration(
                                        color: _avatarColor(i),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(_initials(c),
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nombre,
                                              style: TextStyle(fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: cs.textPrimary)),
                                          const SizedBox(height: 2),
                                          Text(
                                            ciudad.isNotEmpty
                                                ? '$dir · $ciudad'
                                                : dir,
                                            style: TextStyle(fontSize: 10,
                                                color: cs.textHint),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                width: 6, height: 6,
                                                decoration: BoxDecoration(
                                                  color: active
                                                      ? AppColors.statusSuccess
                                                      : AppColors.statusError,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                active ? 'Activo' : 'Inactivo',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: active
                                                        ? AppColors.statusSuccess
                                                        : AppColors.statusError),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right,
                                        color: cs.border, size: 20),
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