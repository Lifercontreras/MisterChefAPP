# LogiGo — App Flutter

Aplicación móvil **LogiGo**, adaptada para la empresa **Mister Chef**. La usan
vendedores y administradores y consume una API REST Laravel desplegada con
HTTPS (por ejemplo, en Railway).

> `mister_chef` es el nombre técnico del paquete Flutter y se conserva junto con
> los repositorios, la URL de Railway y los correos `@misterchef.com`. El nombre
> visible del producto es **LogiGo**.

## Requisitos

- Flutter 3.47.7 / Dart 3.13.5 (o superior).
- Un back de LogiGo accesible por HTTPS.
- Conexión a Internet para el mapa (SDK de Google Maps) y para OSRM.

## Configuración del back

La URL de la API **no se escribe en el código**. Se inyecta en tiempo de
compilación con `--dart-define-from-file`. La app lee la variable
`API_BASE_URL` y le quita la barra final si la tiene.

1. Copia el archivo de ejemplo y completa la URL real:

   ```powershell
   Copy-Item env/prod.example.json env/prod.json
   ```

   Contenido de `env/prod.example.json`:

   ```json
   {
     "API_BASE_URL": "https://TU-APP.up.railway.app/api/v1"
   }
   ```

   `API_BASE_URL` es la **única** variable de `env/prod.json`. El cálculo de
   rutas por carretera usa el servidor público **OSRM** (OpenStreetMap), que no
   necesita clave.

2. Ejecuta la app apuntando a ese archivo:

   ```powershell
   flutter run --dart-define-from-file=env/prod.json
   ```

   Para compilar un APK:

   ```powershell
   flutter build apk --release --dart-define-from-file=env/prod.json
   ```

3. Si falta `API_BASE_URL`, la app muestra una pantalla de ayuda con el
   mensaje: **"Falta API_BASE_URL. Compila con
   --dart-define-from-file=env/prod.json"**.

### Android Studio

1. Abre **Run > Edit Configurations**.
2. Selecciona la configuración de la app Flutter.
3. En **Additional run args** escribe:

   ```text
   --dart-define-from-file=env/prod.json
   ```

4. Aplica y ejecuta normalmente.

> `env/prod.json` está excluido de Git (`.gitignore`). Solo se versiona
> `env/prod.example.json`, que no contiene credenciales.

## Rutas por carretera (OSRM)

La polilínea de la ruta se pide a `https://router.project-osrm.org` con datos de
**OpenStreetMap**. No hay clave de API ni cuenta de facturación de Google
Routes.

- La ruta general del vendedor (`mi_ruta`) se traza por vías con **2 a 50
  paradas**, en el orden de la lista.
- Si OSRM falla o responde 429, la app deja la línea recta como respaldo y un
  refresco posterior (mínimo **2 s**) reintenta; no hay bucle automático.
- La interfaz muestra la atribución obligatoria **"Rutas © OpenStreetMap ·
  OSRM"**.
- El servidor público es de uso razonable no comercial, admite ~1 petición por
  segundo y no garantiza disponibilidad.

## Compilar el APK (Windows)

La app usa la clave del SDK de Google Maps para el mapa base y un keystore
propio para firmar el APK. Ninguna de esas credenciales se versiona.

- `MAPS_API_KEY`: la lee Gradle para el SDK de Google Maps en Android.
- `android/key.properties`: datos del keystore de firma.

### 1. Clave del SDK de Maps (Android)

Agrega la clave a `android/local.properties` (existe si abriste el proyecto en
Android Studio y está ignorado por Git):

```powershell
Add-Content android/local.properties "MAPS_API_KEY=TU_MAPS_API_KEY"
```

También puedes definirla como variable de entorno antes de compilar:

```powershell
$env:MAPS_API_KEY = "TU_MAPS_API_KEY"
```

Gradle la busca primero en `android/local.properties` y luego en la variable de
entorno. Si falta en un build release, el build falla con un mensaje claro; en
debug se usa un valor vacío y se muestra una advertencia.

> `MAPS_API_KEY` es solo para el **mapa base** del SDK de Google Maps. No se usa
> para calcular rutas: eso lo hace OSRM sin llave.

### 2. Keystore y firma

Genera el keystore una sola vez y guárdalo fuera del repositorio:

```powershell
keytool -genkey -v -keystore "$env:USERPROFILE\mister-chef-release.jks" `
  -keyalg RSA -keysize 2048 -validity 10000 -alias mister-chef
```

Crea `android/key.properties` a partir del ejemplo:

```powershell
Copy-Item android/key.properties.example android/key.properties
```

Completa los valores reales. `storeFile` se resuelve relativo a `android/app`,
así que se recomienda una ruta absoluta:

```properties
storeFile=C:/Users/TU_USUARIO/mister-chef-release.jks
storePassword=TU_STORE_PASSWORD
keyAlias=TU_KEY_ALIAS
keyPassword=TU_KEY_PASSWORD
```

`android/key.properties`, `android/local.properties` y los archivos
`.jks`/`.keystore` están ignorados por Git. Si el build release no encuentra
`key.properties`, falla con **"Falta android/key.properties, ver README"** en
lugar de firmar con la clave debug.

### 3. Compilar

```powershell
flutter build apk --release --dart-define-from-file=env/prod.json
```

El APK queda en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

> **Web:** la app está pensada para Android. Si alguna vez compilas web, el
> script de Google Maps de `web/index.html` sigue comentado y usa el placeholder
> de la llave del SDK; no debe contener claves reales en Git. Las rutas por
> carretera siguen saliendo de OSRM y no necesitan clave.

## Ubicación y mapa en tiempo real

- El stream GPS emite cada **10 s** (`AppConstants.locationUpdateInterval`) y
  respeta un mínimo de **8 s** entre envíos exitosos
  (`AppConstants.locationMinSendInterval`).
- En Android corre como servicio en primer plano con notificación **"LogiGo"**;
  en iOS el intervalo no se aplica porque `LocationSettings` no expone
  `intervalDuration`.
- El mapa del administrador refresca solo `GET /location` cada 10 s, sin
  solapar peticiones y pausado en segundo plano.
- En producción se recomienda `LOCATION_STALE_MINUTES=2` para que una ubicación
  deje de mostrarse rápido si el vendedor se desconecta.

## Pruebas

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Línea base actual: **68 pruebas** en `test/` y **126 issues** de análisis
estático (0 errores, 5 warnings, 121 infos).

## Problemas frecuentes

| Problema | Solución |
|---|---|
| "Falta API_BASE_URL" | Crear `env/prod.json` desde el ejemplo y compilar con `--dart-define-from-file=env/prod.json` |
| La ruta se ve recta | OSRM está caído o respondió 429 (máx. ~1 petición/s). Esperar y refrescar: el reintento llega en un refresco posterior (≥ 2 s) |
| Mapa gris o con marca de agua | Revisar `MAPS_API_KEY` y que la facturación del proyecto del SDK de Google Maps esté activa |
| Build release falla por keystore | Crear `android/key.properties` desde `key.properties.example` con los datos reales |
| El vendedor no aparece en el mapa del administrador | La ubicación es obsoleta tras `LOCATION_STALE_MINUTES` (se recomienda 2 en producción) o el rastreo está detenido |
| 429 al enviar ubicación | Rate limit de 30 envíos/min en `POST /location`; el throttle local de 8 s evita llegar al límite |
| 409 al aplicar la distribución | El reparto cambió desde la vista previa; recalcular y volver a aplicar |
