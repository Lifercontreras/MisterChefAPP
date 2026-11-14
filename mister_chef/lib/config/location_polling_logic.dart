/// Decide si debe ejecutarse un ciclo de refresco automático del mapa.
///
/// Lógica pura, sin Flutter ni red: la pantalla solo aporta si ya hay una
/// petición en vuelo y si la app está en pausa. Con un ciclo cada 10 s
/// (AppConstants.locationUpdateInterval) se evita solapar peticiones y
/// refrescar en segundo plano.
library;

/// Indica si el ciclo automático debe correr.
///
/// Devuelve `false` si [requestInFlight] es `true` (la petición anterior aún
/// no terminó) o si [appPaused] es `true` (la app no está visible).
bool shouldRunLocationPoll({
  required bool requestInFlight,
  required bool appPaused,
}) {
  return !requestInFlight && !appPaused;
}
