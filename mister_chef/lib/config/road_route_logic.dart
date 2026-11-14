/// Lógica pura para decidir cuándo pedir la ruta por vías a OSRM.
///
/// Sin Flutter ni red: recibe el tamaño y la firma de los puntos, la última
/// firma que se calculó con éxito y el instante de la última petición. Así la
/// pantalla puede evitar peticiones repetidas y respetar el uso razonable del
/// servidor público (máximo una petición por segundo).
library;

/// Indica si hace falta pedir la ruta por vías.
///
/// Devuelve `false` cuando no hay puntos suficientes ([pointCount] fuera del
/// rango 2–50), cuando [signature] ya se resolvió con éxito
/// ([lastSuccessSignature]) o cuando pasaron menos de [minInterval] desde
/// [lastRequestAt]. En cualquier otro caso devuelve `true`.
bool shouldRequestRoadRoute({
  required int pointCount,
  required String signature,
  required String? lastSuccessSignature,
  required DateTime? lastRequestAt,
  required DateTime now,
  Duration minInterval = const Duration(seconds: 2),
}) {
  if (pointCount < 2 || pointCount > 50) return false;
  if (signature == lastSuccessSignature) return false;
  if (lastRequestAt != null && now.difference(lastRequestAt) < minInterval) {
    return false;
  }
  return true;
}
