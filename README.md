# firetv-debloat

Script para limpiar un Fire TV (Fire OS 7) por ADB: quita anuncios, telemetría,
tutoriales y apps de Amazon que no se usan, bloquea las actualizaciones OTA y
deja Projectivy Launcher como pantalla de inicio. Sin root y sin exploits.

Probado en un **Fire TV Stick 3.ª gen (AFTSS)** con **Fire OS 7.7.1.7**.

## Requisitos

- `adb` (paquete `android-tools-adb` / `platform-tools`)
- El Stick en la misma red y con **Depuración ADB** activada:
  Ajustes → Mi Fire TV → Información → pulsa el nombre del dispositivo 7 veces,
  luego Ajustes → Mi Fire TV → Opciones de desarrollador → Depuración ADB.
- La primera vez el Stick pide aceptar la huella RSA: marca **"Aceptar siempre"**.

## Uso

```bash
chmod +x firetv-debloat.sh

./firetv-debloat.sh 192.168.1.50 status     # ver estado
./firetv-debloat.sh 192.168.1.50 debloat    # quitar bloat
./firetv-debloat.sh 192.168.1.50 ota        # bloquear actualizaciones
./firetv-debloat.sh 192.168.1.50 launcher --apk ~/projectivy.apk
./firetv-debloat.sh 192.168.1.50 all --apk ~/projectivy.apk
./firetv-debloat.sh 192.168.1.50 restore    # deshacer todo
```

Añade `--dry-run` para ver los comandos sin tocar el dispositivo.

Si no pones puerto se usa `5555`: `192.168.1.50:5555`.

## Qué desactiva

| Grupo | Paquetes |
|-------|----------|
| Anuncios / métricas | `hybridadidservice`, `kso.blackbird`, `media.recommendations`, `tv.acr`, `tv.fw.metrics`, `wirelessmetrics.service`, `perfc`, `perfcollection`, `tv.developer.dataservice`, `hedwig`, `stillwatching.activity` |
| Tienda en TV | `shoptv.client`, `shoptv.firetv.client` |
| Apps Amazon sin uso | `minitv`, `bueller.music`, `bueller.photos`, `tahoe`, `ceviche`, `gamehub` |
| Tutoriales / soporte | `storm.lightning.tutorial`, `tmm.tutorial`, `sneakpeek`, `logan`, `katoch`, `tv.support`, `tv.releasenotes` |
| Stubs dummy | `alarmclock`, `calendar`, `contacts`, `gallery`, `music`, `settings` |
| OTA (`ota`) | `device.software.ota`, `device.software.ota.override`, `tv.forcedotaupdater.v2` |

No se toca el launcher de Amazon, SystemUI, WebView, `tcomm` ni los servicios de
autenticación: la interfaz y las apps siguen funcionando.

**No se incluye `com.amazon.imp`**: es de identidad/cuentas y desactivarlo
provoca un bucle de crashes.

Algunos paquetes están protegidos por Fire OS y el script los deja como están
(`ftvads.deeplinking`, `device.metrics`, `diode`, `device.logmanager`,
`keypolicymanager`, `tv.csapp`). Haría falta root.

## Launcher (Projectivy)

Fire OS 7.7.1.7 ya no permite cambiar el launcher por ADB
(`set-home-activity` se ignora y `pm disable-user com.amazon.tv.launcher`
devuelve "Cannot disable a protected package"). El script usa la vía que sí
funciona: el **override por accesibilidad de Projectivy**.

1. Consigue el APK (Play Store en el móvil, APKMirror, etc.) y pásalo con `--apk`.
2. El script lo instala, lo marca como home preferido y activa su servicio de
   accesibilidad y el listener de notificaciones.
3. Paso manual en la TV: Projectivy → engranaje → **Ajustes de Projectivy →
   General → "Reemplazar el launcher actual"** (ON).

Resultado: el botón HOME abre el launcher de Amazon medio segundo y Projectivy
recupera el foco en 2-4 s; al arrancar también sale Projectivy.

Si el HOME sigue yendo a Amazon, comprueba que el servicio sigue activo:

```bash
adb shell settings get secure enabled_accessibility_services
```

Debe contener `com.spocky.projengmenu/...ProjectivyAccessibilityService`.

## Revertir

```bash
./firetv-debloat.sh 192.168.1.50 restore
```

Reactiva todos los paquetes y devuelve el home a Amazon. Projectivy no se
desinstala (`adb uninstall com.spocky.projengmenu` si lo quieres fuera).

## Avisos

- Bloquear OTA (`ota`) significa no recibir parches de seguridad ni mejoras.
- Un update de Fire OS puede revocar el override de accesibilidad; se vuelve a
  activar desde los ajustes de Projectivy, no es permanente.
- Todo es reversible con `restore`, pero úsalo bajo tu responsabilidad.

## Licencia

MIT
