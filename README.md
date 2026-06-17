# Mister Chef APP — Documentación del Proyecto

## Descripción General

**Mister Chef APP** es una aplicación móvil desarrollada en **Flutter/Dart** para la gestión de ventas y distribución de la empresa Mister Chef. Permite a vendedores registrar pedidos, gestionar clientes y seguir rutas de entrega, mientras que los administradores supervisan empleados, inventario y métricas en tiempo real.

---

## Arquitectura del Proyecto

El proyecto sigue una **arquitectura por capas** organizada en carpetas dentro de `lib/`:

```
lib/
├── main.dart                  # Punto de entrada; configura providers y rutas
├── config/
│   ├── app_colors.dart        # Paleta de colores y helper de tema claro/oscuro
│   ├── app_routes.dart        # Rutas nombradas de navegación
│   ├── app_theme.dart         # Temas Material 3 (claro y oscuro)
│   └── constants.dart         # URL base, endpoints, roles y claves SharedPreferences
├── models/                    # Modelos de datos (estructuras JSON de la API)
├── providers/                 # Estado global con ChangeNotifier (Provider)
│   └── accessibility_provider.dart  # Modo oscuro, fuente, escala y saturación
├── services/                  # Capa de acceso a datos (API REST)
│   ├── api_service.dart       # Cliente HTTP genérico (Singleton)
│   ├── auth_service.dart      # Login, logout, sesión local
│   ├── order_service.dart     # Facturas: listar, crear, confirmar, anular
│   ├── customer_service.dart  # Clientes: CRUD completo
│   ├── product_service.dart   # Productos: CRUD + stock + estado
│   ├── chatbot_service.dart   # Comunicación con el asistente IA
│   ├── location_service.dart  # GPS del vendedor + departamentos y ciudades
│   ├── route_service.dart     # Rutas, paradas, Google Directions y sugerencias
│   ├── employee_service.dart  # Empleados: CRUD + cambio de estado
│   ├── maps_service.dart      # Integración con Google Maps
│   └── storage_service.dart   # Persistencia local auxiliar
├── screens/                   # Pantallas de la aplicación
│   ├── auth/                  # Splash, Login, Cambio de contraseña
│   ├── home/                  # Dashboard principal
│   ├── orders/                # Lista, detalle y nuevo pedido
│   ├── customers/             # Lista, detalle y creación de clientes
│   ├── admin/                 # Empleados, productos, mapa en vivo
│   ├── chatbot/               # Chat con asistente IA
│   ├── route/                 # Mapa de ruta del vendedor
│   └── settings/              # Configuración y accesibilidad
├── widgets/                   # Componentes reutilizables
└── utils/                     # Formateadores, validadores y helpers
```

---

## Roles de Usuario

| Rol            | Código | Acceso                                                                 |
|----------------|--------|------------------------------------------------------------------------|
| Administrador  | `'A'`  | Panel completo: pedidos, clientes, empleados, productos, mapa en vivo  |
| Vendedor       | `'V'`  | Pedidos propios, clientes asignados, ruta del día, chatbot IA          |

---

## Módulos Principales

### 1. Autenticación (`auth_service.dart`)
- Login con email y contraseña via `POST /api/v1/login`.
- Almacenamiento local del token Bearer en `SharedPreferences`.
- Soporte para primer inicio de sesión (fuerza cambio de contraseña).
- Logout con invalidación del token en el servidor.

### 2. Pedidos / Facturas (`order_service.dart`)
- Listar facturas con filtros por estado (`P`, `C`, `A`) y fecha.
- Crear facturas con cliente y lista de productos.
- Confirmar (descuenta stock) o anular facturas.
- Estadísticas del día para el dashboard.

### 3. Clientes (`customer_service.dart`)
- CRUD completo de clientes con coordenadas GPS.
- Los vendedores solo ven sus clientes; los admins ven todos.
- Filtro por estado activo/inactivo.

### 4. Productos (`product_service.dart`)
- Listado con filtro por disponibilidad.
- Alertas de stock bajo (`/products/low-stock`).
- Gestión de stock y estado activo/inactivo.

### 5. Rutas de Entrega (`route_service.dart`)
- Paradas asignadas al vendedor con estado en tiempo real.
- Navegación a cada cliente via Google Directions API.
- El admin distribuye rutas automáticamente.
- Sistema de sugerencias de cambio de ruta con aprobación/rechazo.

### 6. Chatbot IA (`chatbot_service.dart`)
- Asistente virtual que responde preguntas sobre ventas, clientes y stock.
- Soporta contexto de ubicación GPS para respuestas geográficas.
- Timeout de 60 segundos por la naturaleza asíncrona de las respuestas IA.

### 7. Accesibilidad (`accessibility_provider.dart`)
- Modo claro/oscuro persistente.
- Escala de fuente ajustable (rango 0.7× – 1.4×).
- Fuente especial para dislexia (Lexend).
- Filtro de saturación de color (normal, alta, baja, escala de grises).

---

## Convenciones de Documentación del Código

El proyecto usa la convención estándar de Dart/Flutter:

- `///` (triple barra): **docstrings** de clases, métodos y propiedades públicas. Aparecen en la documentación generada automáticamente por `dart doc`.
- `//` (doble barra): **comentarios inline** para explicar lógica interna, decisiones de diseño o aclaraciones puntuales.
- Los bloques `// ══════` delimitan secciones importantes dentro de servicios, mostrando el endpoint, estructura del cuerpo y respuesta esperada.

---

## Configuración de la API

La URL base y todos los endpoints se definen en `lib/config/constants.dart`.
Para cambiar de ambiente (local → staging → producción), solo se modifica `AppConstants.baseUrl`.

```
URL base actual: http://192.168.1.32:8000/api/v1
```

---

## Tecnologías y Dependencias Principales

| Paquete                     | Propósito                                          |
|-----------------------------|----------------------------------------------------|
| `provider`                  | Gestión de estado global con `ChangeNotifier`      |
| `http`                      | Peticiones HTTP a la API REST de Laravel           |
| `shared_preferences`        | Persistencia local (token, preferencias)           |
| `google_fonts`              | Tipografías Inter y Lexend                         |
| `google_maps_flutter`       | Mapa interactivo en pantallas de ruta              |
| `geolocator`                | Obtención de coordenadas GPS del dispositivo       |
| `flutter_polyline_points`   | Decodificación de rutas de Google Directions       |

---

## Instalación y Ejecución

```bash
# Clonar el repositorio
git clone https://github.com/Lifercontreras/MisterChefAPP.git
cd MisterChefAPP/mister_chef

# Instalar dependencias
flutter pub get

# Ejecutar en modo debug
flutter run

# Generar build de producción (Android)
flutter build apk --release
```

> **Requisito**: Tener el servidor Laravel corriendo en la red local con la IP configurada en `AppConstants.baseUrl`.

## GIT

## Estrategia de Ramas

El proyecto utiliza dos ramas principales:

- `main`: contiene la versión estable del proyecto.
- `develop`: contiene los avances de desarrollo antes de ser integrados a la versión estable.

Flujo de trabajo:

1. Los cambios se realizan en la rama `develop`.
2. Una vez probados y validados, los cambios se integran en la rama `main`.
3. La rama `main` debe mantenerse siempre en un estado estable y funcional.

## Convención de Commits

Para mantener un historial organizado se utilizarán los siguientes prefijos:

| Prefijo | Descripción |
|----------|------------|
| feat | Nueva funcionalidad |
| fix | Corrección de errores |
| docs | Cambios en documentación |
| style | Cambios de formato o estilos |
| refactor | Reestructuración de código |
| chore | Tareas de mantenimiento |

Ejemplos:

```bash
git commit -m "feat: agregar pantalla de clientes"
git commit -m "fix: corregir error de autenticación"
git commit -m "docs: actualizar README"
```