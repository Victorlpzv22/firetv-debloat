# firetv-debloat

Debloat a Fire TV (Fire OS 7) over ADB: strips ads, telemetry, tutorials and
unused Amazon apps, blocks OTA updates, and sets Projectivy Launcher as the home
screen. No root, no exploit.

Tested on a **Fire TV Stick 3rd gen (AFTSS)** running **Fire OS 7.7.1.7**.

## Requirements

- `adb` (`android-tools-adb` / `platform-tools`)
- Stick on the same network with **ADB debugging** enabled:
  Settings → My Fire TV → About → click the device name 7 times, then
  Settings → My Fire TV → Developer options → ADB debugging.
- On first connection the Stick asks you to accept the RSA fingerprint:
  tick **"Always allow"**.

## Usage

```bash
chmod +x firetv-debloat.sh

./firetv-debloat.sh 192.168.1.50 status     # show current state
./firetv-debloat.sh 192.168.1.50 debloat    # remove bloat
./firetv-debloat.sh 192.168.1.50 ota        # block OTA updates
./firetv-debloat.sh 192.168.1.50 launcher --apk ~/projectivy.apk
./firetv-debloat.sh 192.168.1.50 all --apk ~/projectivy.apk
./firetv-debloat.sh 192.168.1.50 restore    # undo everything
```

Add `--dry-run` to print the commands without touching the device.

If you omit the port, `5555` is used: `192.168.1.50:5555`.

## What gets disabled

| Group | Packages |
|-------|----------|
| Ads / metrics | `hybridadidservice`, `kso.blackbird`, `media.recommendations`, `tv.acr`, `tv.fw.metrics`, `wirelessmetrics.service`, `perfc`, `perfcollection`, `tv.developer.dataservice`, `hedwig`, `stillwatching.activity` |
| On-TV store | `shoptv.client`, `shoptv.firetv.client` |
| Unused Amazon apps | `minitv`, `bueller.music`, `bueller.photos`, `tahoe`, `ceviche`, `gamehub` |
| Tutorials / support | `storm.lightning.tutorial`, `tmm.tutorial`, `sneakpeek`, `logan`, `katoch`, `tv.support`, `tv.releasenotes` |
| Dummy stubs | `alarmclock`, `calendar`, `contacts`, `gallery`, `music`, `settings` |
| OTA (`ota` command) | `device.software.ota`, `device.software.ota.override`, `tv.forcedotaupdater.v2` |

The Amazon launcher, SystemUI, WebView, `tcomm` and the authentication services
are left alone, so the UI and your apps keep working.

**`com.amazon.imp` is deliberately excluded**: it handles identity/accounts and
disabling it causes a crash loop.

Some packages are protected by Fire OS and are left as they are
(`ftvads.deeplinking`, `device.metrics`, `diode`, `device.logmanager`,
`keypolicymanager`, `tv.csapp`). Those would need root.

## Launcher (Projectivy)

Fire OS 7.7.1.7 no longer lets you change the launcher over ADB
(`set-home-activity` is ignored and `pm disable-user com.amazon.tv.launcher`
fails with "Cannot disable a protected package"). The script uses the approach
that does work: **Projectivy's accessibility-based launcher override**.

1. Get the APK (Play Store on a phone, APKMirror, etc.) and pass it with `--apk`.
2. The script installs it, sets it as the preferred home activity, and enables
   its accessibility service plus the notification listener.
3. Manual step on the TV: Projectivy → gear icon → **Projectivy settings →
   General → "Replace current launcher"** (ON).

Result: the HOME button briefly shows Amazon's launcher and Projectivy takes the
foreground back within 2-4 s; it also comes up on boot.

If HOME still lands on Amazon, check the service is still enabled:

```bash
adb shell settings get secure enabled_accessibility_services
```

It must contain `com.spocky.projengmenu/...ProjectivyAccessibilityService`.

## Revert

```bash
./firetv-debloat.sh 192.168.1.50 restore
```

Re-enables every package and points the home activity back to Amazon.
Projectivy is not uninstalled (`adb uninstall com.spocky.projengmenu` if you want
it gone).

## Caveats

- Blocking OTA (`ota`) means no security patches and no feature updates.
- A Fire OS update can revoke the accessibility override; just turn it back on in
  Projectivy's settings, it is not permanent.
- Everything is reversible with `restore`, but use it at your own risk.

## License

MIT
