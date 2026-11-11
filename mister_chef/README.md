# Mister Chef — App Flutter

Aplicación móvil de Mister Chef para vendedores y administradores. Consume una
API REST Laravel desplegada con HTTPS (por ejemplo, en Railway).

## Requisitos

- Flutter 3.47.7 / Dart 3.13.5 (o superior).
- Un back de Mister Chef accesible por HTTPS.

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
     "API_BASE_URL": "https://TU-APP.up.railway.app/api/v1",
     "DIRECTIONS_API_KEY": "TU_DIRECTIONS_API_KEY"
   }
   ```

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

## Compilar el APK (Windows)

La app usa dos claves de Google distintas y un keystore propio para firmar el
APK. Ninguna de esas credenciales se versiona.

- `MAPS_API_KEY`: la lee Gradle para el SDK de Google Maps en Android.
- `DIRECTIONS_API_KEY`: la lee Dart para calcular rutas con Google Directions.
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

### 2. Claves de Dart

Copia el archivo de ejemplo y completa la URL del back y la clave de
Directions:

```powershell
Copy-Item env/prod.example.json env/prod.json
```

`env/prod.json` debe quedar así (con tus valores reales):

```json
{
  "API_BASE_URL": "https://TU-APP.up.railway.app/api/v1",
  "DIRECTIONS_API_KEY": "TU_DIRECTIONS_API_KEY"
}
```

Si `DIRECTIONS_API_KEY` está vacía, al intentar trazar una ruta la app muestra
un mensaje de error controlado y no se cierra.

### 3. Keystore y firma

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

### 4. Compilar

```powershell
flutter build apk --release --dart-define-from-file=env/prod.json
```

El APK queda en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

> **Web:** la app está pensada para Android. Si alguna vez compilas web,
> reemplaza localmente el placeholder `TU_DIRECTIONS_API_KEY` en
> `web/index.html`; ese archivo no debe contener claves reales en Git.

## Pruebas

```powershell
flutter analyze --no-pub
flutter test --no-pub
```
