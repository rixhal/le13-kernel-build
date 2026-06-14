# le13-isa-build — ISA 22.3.14 Source Build mit SECURE_PATH-Patch

> ⚠️ **Repo umgewidmet (2026-06-12)**
> Ursprünglich als Kernel-Build-Repo (`CONFIG_DMABUF_HEAPS_RESERVED=y`) gestartet.
> Dieser Kernel-Flag existiert NICHT (Source-Analyse 12.06.2026).
> Siehe `references/dmabuf-heaps-disproof.md` und `crackberry5-widevine-debug` Skill v6.0.0.

## Warum

Auf LE13/RPi5 produziert Crunchyroll (Widevine DRM) RGB-Testbild.
Root Cause: ISA `GetCapabilities()` gibt nur `SINGLE_DECRYPT`, kein `SECURE_PATH` →
Kodi wählt FFmpeg-Software-Decode → Pi 5 hat kein H.264-V4L2 → Testbild.

**Fix: ISA aus Source bauen mit SECURE_PATH-Patch in GetCapabilities().**

## Patches

### LE13 Patch: WVCencSingleSampleDecrypter.cpp GetCapabilities()

```cpp
  // ALT (Zeile ~164): caps.flags = Capabilities::SUPPORTS_DECODING;
  // NEU:
  caps.flags = Capabilities::SUPPORTS_DECODING | Capabilities::SECURE_PATH | Capabilities::ANNEXB_REQUIRED;
```

Flags laut `DrmEngineDefines.h`:
| LE13 Flag | Value | Zweck |
|-----------|-------|-------|
| `SUPPORTS_DECODING` | 1 | Basis-Decoding |
| `SECURE_PATH` | 2 | HW Secure Decode |
| `ANNEXB_REQUIRED` | 4 | AnnexB-Format |
| `INVALID_STATUS` | 64 | Error |

### Crunchyroll force_secure_decoder entfernen

**Datei:** `plugin.video.crunchyroll/resources/lib/videoplayer.py` Zeile 183

```python
# ALT: item.setProperty("inputstream.adaptive.manifest_config", json.dumps({"force_secure_decoder": True}))
# NEU:
item.setProperty("inputstream.adaptive.manifest_config", "{}")
```

ISA 22.3.14 lehnt `force_secure_decoder` in JEDER Form ab.
Leeres JSON `{}` verhindert den Parse-Fehler → `NOSECUREDECODER=true` in Settings greift.

## Build-Procedure

```
Build-Host:           crackberry (Pi 4, aarch64 Debian)
ISA-Version:          22.3.11 (stable, SECURE_PATH bereits aktiv)
Fallback:             Nexus Branch (bei fehlendem isa-22.3.11)
```

### Prerequisites

```bash
sudo apt install g++ cmake make git
# pugixml (static build empfohlen, fehlt auf LE13)
git clone https://github.com/zeux/pugixml.git
cd pugixml && g++ -shared -o libpugixml.so.1 -fPIC -O2 src/pugixml.cpp -I src/
```

### Build

```bash
# 1. Source pullen
git clone --branch 22.3.14.1-Nexus --depth 1 https://github.com/xbmc/inputstream.adaptive.git
cd inputstream.adaptive

# 2. Patch anwenden
# Patch: inputstream.adaptive/src/decrypters/widevine/WVCencSingleSampleDecrypter.cpp
# Zeile ~164: caps.flags = SUPPORTS_DECODING | SECURE_PATH | ANNEXB_REQUIRED

# 3. CMake konfigurieren
mkdir build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=/path/to/aarch64-linux-gnu.cmake \
  -DBUILD_SHARED_LIBS=ON \
  -DENABLE_PUGIXML_STATIC=ON \
  -DCMAKE_INSTALL_PREFIX=/tmp/isa-install

# 4. Bauen
make -j$(nproc)

# 5. Installieren
make install
# Output: /tmp/isa-install/lib/inputstream.adaptive.so.22.3.14
```

Siehe `libreelec-management` Skill → `references/isa-source-build.md` für vollständige Doku.

## Known Issues

### RGB-Testpattern trotz SECURE_PATH

Der Pi5 (RPi5) hat im LE13-Kernel **keinen H.264-HW-Decoder** (`rpi_h264_dec` fehlt, nur `rpi_hevc_dec`).
SECURE_PATH signalisiert Kodi "HW-Secure-Decode", aber ohne H.264-HW-Pfad fällt Kodi auf Software-Decode via FFmpeg zurück.

Das sichtbare RGB-Testpattern ist **kein CPU-Overload** — der Pi5-CPU schafft H.264-SW-Decode für 1080p (laut Pi-Gründer).
Testpattern = **CDM-Verweigerung**: `NOSECUREDECODER=false` + `force_secure_decoder=true` → CDM gibt Testpattern bewusst aus.

**Fix (auf crackberry5):**
```bash
# 1. NOSECUREDECODER in ISA-Settings setzen
sed -i 's|default="true">0|default="true">1|' /storage/.kodi/addons/inputstream.adaptive/settings.xml
# Value 1 = NOSECUREDECODER aktiviert → CDM liefert echten Content

# 2. force_secure_decoder aus Crunchyroll entfernen
sed -i 's/item.setProperty("inputstream.adaptive.manifest_config", json.dumps({"force_secure_decoder": True}))/item.setProperty("inputstream.adaptive.manifest_config", "{}")/' /storage/.kodi/addons/plugin.video.crunchyroll/resources/lib/videoplayer.py
```

### auto-update.sh — cd-Bug (2026-06-14 Fixed)

Nach dem Kernel-Source-Check in `[2/3]` fehlte `cd "$SCRIPT_DIR"`. Das Arbeitsverzeichnis blieb in `kernel-src/`, sodass `./pull-source.sh` und `./build.sh` mit "No such file" (exit 127) fehlschlugen.

**Fix:** `cd "$SCRIPT_DIR"` nach dem Kernel-Check-Block eingefügt (auto-update.sh Zeile 56).

### build.sh — ISA Nexus API-Inkompatibilität (2026-06-14 Fixed)

Der Nexus-Branch `inputstream.adaptive/` nutzt `AP4_AvcFrameParser::ReadGolomb`, das im aktuellen bento4 entfernt wurde → Compile Error.
`isa-22.3.11/` hat eine lokale `ReadGolomb()`-Funktion und baut sauber. Zudem ist SECURE_PATH in v22.3.11 GetCapabilities() bereits aktiv (kein Patch nötig).

**Fix:** `build.sh` ISA_DIR auf `isa-22.3.11` umgestellt. Bei fehlendem Verzeichnis Fallback auf Nexus-Klon.

### PITFALLS

- **libpugixml.so.1 fehlt auf LE13** → statisch linken (`-DENABLE_PUGIXML_STATIC=ON`) oder `libpugixml.so.1` nach `/storage/.kodi/addons/mesa-le12/lib/` kopieren
- **LE13 CXXABI** → GCC 13/14 baut CXXABI_1.3.15 → LE13 libstdc++ braucht das. GCC ≤13 für Kompatibilität.
- **Kodi-Headers vom exakten LE13-Commit** → `git clone --depth 1 https://github.com/LibreELEC/LibreELEC.tv.git` → `projects/RPi/devices/RPi5/`
- **Docker Images nicht verfügbar** für LE.tv Build-System → direkter cmake-Build
- **`patchelf` korrumpiert `dri_gbm.so`** (68KB→136KB) → nicht verwenden

## Deploy (auf crackberry5)

```bash
# 1. ISA .so kopieren
ssh root@crackberry5 'systemctl stop kodi; sleep 2; killall kodi.bin 2>/dev/null'
cd /tmp/isa-install/lib/
scp inputstream.adaptive.so.22.3.14 root@crackberry5:/storage/.kodi/addons/inputstream.adaptive/

# 2. guisettings.xml patchen (REMOTE)
ssh root@crackberry5 << 'EOF'
  # DRMPRIME ausschalten
  sed -i 's|<setting id="videoplayer.useprimerenderer" default="true">0</setting>|<setting id="videoplayer.useprimerenderer" default="false">2</setting>|' /storage/.kodi/userdata/guisettings.xml
EOF

# 3. advancedsettings.xml schreiben
cat > /tmp/advancedsettings.xml << 'XML'
<advancedsettings>
  <loglevel>2</loglevel>
  <video>
    <useprimerenderer>2</useprimerenderer>
  </video>
</advancedsettings>
XML
scp /tmp/advancedsettings.xml root@crackberry5:/storage/.kodi/userdata/

# 4. playercorefactory.xml (erzwingt VideoPlayer=Software-Decode)
cat > /tmp/playercorefactory.xml << 'XML'
<playercorefactory>
  <players>
    <player name="VideoPlayer" type="VideoPlayer" audio="true" video="true" />
  </players>
  <rules action="prepend">
    <rule video="true" player="VideoPlayer" />
  </rules>
</playercorefactory>
XML
scp /tmp/playercorefactory.xml root@crackberry5:/storage/.kodi/userdata/

# 5. Crunchyroll force_secure_decoder entfernen
ssh root@crackberry5 << 'EOF'
  sed -i 's/item.setProperty("inputstream.adaptive.manifest_config", json.dumps({"force_secure_decoder": True}))/item.setProperty("inputstream.adaptive.manifest_config", "{}")/' /storage/.kodi/addons/plugin.video.crunchyroll/resources/lib/videoplayer.py
  find /storage/.kodi/addons/plugin.video.crunchyroll/ -name '__pycache__' -exec rm -rf {} +
EOF

# 6. Kodi starten
ssh root@crackberry5 'systemctl start kodi'

# 7. Verify
sleep 15
ssh root@crackberry5 'grep -E "RendererDRMPRIME|LinuxRendererGLES|Addon Manager.*inputstream" /storage/.kodi/temp/kodi.log | tail -5'
```

## Architektur-Patterns (beibehalten aus Vorgänger-Repo)

### 1. Version-Tracker
- `.isa-build-version` auf Target → `deploy.sh` prüft vor Deployment
- `CHANGELOG.md` im Repo

### 2. Idempotenz
- `deploy.sh` vergleicht MD5 von lokalem und Target-ISA `.so`
- Bei Identität → skip

### 3. Rollback
- Backup alter `.so` vor Deploy (`.bak.YYYYMMDD`)
- Max 3 Backups (Auto-Cleanup)

### 4. Research→Build-Feed
- `research-patches/` für Patch-Dateien
- `apply-patches.sh` merged neue Patches

### 5. Dual-Remote-Sync
- GitHub: `git@github.com:rixhal/le13-kernel-build.git`
- Forgejo: `https://git.richie.fyi/rixhal/le13-kernel-build.git`

## Verifikation (Vor-Ort, remote nicht möglich)

```bash
# 1. Renderer checken
grep "LinuxRendererGLES\\|RendererDRMPRIMEGLES" /storage/.kodi/temp/kodi.log
# Erwartet: LinuxRendererGLES (Pixel Shaders, kein DRMPRIME)

# 2. Codec checken
grep "CDVDVideoCodec" /storage/.kodi/temp/kodi.log
# Erwartet: CDVDVideoCodecFFmpeg (Software, kein V4L2)

# 3. ISA Version checken
grep "Found addon.*inputstream" /storage/.kodi/temp/kodi.log
# Erwartet: inputstream.adaptive v22.3.14.1

# 4. DRM/Crunchyroll checken
grep -E "Widevine|Decrypt|CDM|license" /storage/.kodi/temp/kodi.log | tail -10
```

## Referenzen

- `libreelec-management` Skill → `references/isa-source-build.md`
- `crackberry5-widevine-debug` Skill → `references/dmabuf-heaps-reserved-disproof.md`
- [xbmc/inputstream.adaptive](https://github.com/xbmc/inputstream.adaptive) — ISA 22.3.14.1-Nexus Branch
- [LibreELEC.tv](https://github.com/LibreELEC/LibreELEC.tv) — LE13 Config + Bauanleitung
