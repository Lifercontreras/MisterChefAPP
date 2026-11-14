/// Lógica pura para decidir qué clientes de una ruta deben mostrarse.
///
/// Sin Flutter ni red: recibe la lista cruda que devuelve `GET /routes` y
/// devuelve solo los clientes activos. Es tolerante al tipo del campo
/// `status` porque el backend puede enviarlo como booleano, entero o texto.
library;

/// Devuelve una nueva lista con los clientes activos de [clients].
///
/// Descarta un cliente cuando su `status` es `false`, `0`, `'0'` o
/// `'false'` (sin distinguir mayúsculas ni espacios). Conserva el cliente
/// cuando es `true`, `1`, `'1'`, `'true'`, cuando el campo falta o es
/// `null`, y ante cualquier valor desconocido (criterio defensivo: no se
/// oculta un cliente que no se puede clasificar como inactivo).
List<Map<String, dynamic>> activeRouteClients(
  List<Map<String, dynamic>> clients,
) {
  return clients.where(_isActive).toList();
}

bool _isActive(Map<String, dynamic> client) {
  final status = client['status'];
  if (status == null) return true;
  if (status is bool) return status;
  if (status is num) return status != 0;
  if (status is String) {
    final normalized = status.trim().toLowerCase();
    if (normalized == '0' || normalized == 'false') return false;
  }
  return true;
}
