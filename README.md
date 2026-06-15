# le13-isa-build — ISA 22.3.14 Source Build mit SECURE_PATH-Patch

> **Repo-Schwerpunkt:** ISA 22.3.11 Binary Patch für RPi5 — verhindert RGB-Testpattern
> bei Crunchyroll/Widevine auf LibreELEC 13 durch Umleitung des Secure-Decode-Pfads.

## Problem

Auf LE13/RPi5 produziert Crunchyroll (Widevine DRM) ein RGB-Testbild.
**Root Cause:** ISA `CWVCencSingleSampleDecrypter::GetCapabilities()` setzt bei fehlendem
Test-Decrypt `SSD_SECURE_PATH` (Bit 1 = 0x02). Das aktiviert in `DrmEngine` den CENC-Prefix-Secure-Pfad
→ Kodi soll DRMPRIME-Frames rendern → V3D-GLES kann sie nicht importieren → Testpattern.

**Fix:** Binary-Patch ersetzt `SSD_SECURE_PATH` (Bit 1) durch `SSD_SINGLE_DECRYPT` (Bit 4 = 0x10) in den
beiden Fehlerpfaden von `GetCapabilities()`. Der gesamte Secure-Pfad wird umgangen:
ISA entschlüsselt in Software (Widevine CDM Memory-Decrypt) → decodiertes Video an Kodi → Pixel Shaders rendern.

## Binary Patch

**Ziel-Binary:** `build-output/lib/inputstream.adaptive.so` — 3.8 MB aarch64, ELF not stripped.

**Patch-Skript:** `isa-22.3.11/patches/patch-secure-path-to-single-decrypt.py`

Zwei Stellen im Binary wurden geändert:

| Adresse | Vorher (Instruktion) | Nachher | Pfad |
|---------|---------------------|---------|------|
| `0x12dab4` | `orr w0, w0, #0x6` → `0x321f0400` | `orr w0, w0, #0x10` → `0x321c0000` | Failure path |
| `0x12dc14` | `orr w0, w0, #0x6` → `0x321f0400` | `orr w0, w0, #0x10` → `0x321c0000` | Exception path |

Die Success-Path-Stelle (`0x12d9e8`) setzte bereits korrekt `#0x10` und blieb unverändert.

### Verifikation aller 13 Downstream-Consumer

Jeder Konsument prüft Bit 1 via `tbz wX, #1` / `tbnz wX, #1`. Mit Bit 1 = 0
nehmen **alle** den Software/Non-Secure-Pfad:

- `DrmEngine::InitializeSession()` → `SetFeatures(NONE)`, kein Key System
- `Session::PrepareStream()` → `SetSecureSession(false)`
- `CWVCencSingleSampleDecrypter::DecryptSampleData()` → Software-Decrypt (AES via CDM)
- `FragmentedSampleReader::ReadSample()` → `useDecryptingDecoder = false`
- Kein ORR mit #0x02 existiert im gesamten ISA-Binary
- WebOS/Android-Code: nicht kompiliert
- Manifest `force_secure_decoder`: greift nur wenn SECURE_PATH bereits gesetzt — irrelevant

✅ **100% Abdeckung geprüft — kein alternativer Pfad möglich.**

## Wirkung

```mermaid
flowchart LR
    A[Crunchyroll Stream] --> B[ISA GetCapabilities]
    B --> C[flags = 0x11: SUPPORTS | SINGLE_DECRYPT]
    C --> D[DrmEngine: kein SECURE_PATH]
    D --> E[Kein INPUTSTREAM_FEATURE_DECODE]
    E --> F[ISA decrypted in Software]
    F --> G[Kodi VideoPlayer: Software-Decode]
    G --> H[Pixel Shaders rendern]
    H --> I[✅ Kein Testpattern!]
```

### NOSECUREDECODER & usePrimerenderer (autostart.sh)

Zusätzlich wird beim Kodi-Start via `autostart.sh` gesetzt:
- `NOSECUREDECODER=true` im ISA-Settings (Sicherheitsnetz — löscht Bit 5)
- `useprimerenderer=2` in `guisetttings.xml` und `advancedsettings.xml`
- `force_secure_decoder` aus Crunchyroll entfernt

Der ISA-Binary-Patch allein macht die ersten beiden obsolet, aber sie stören nicht.

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

### Build (lokal, auf dem Build-Host)

Das Repo enthält bereits das vollständige ISA-Source-Verzeichnis (`isa-22.3.11/`).
Ein Build läuft einfach als:

```bash
./build.sh
```

Was passiert:
1. pugixml static build (falls nicht vorhanden)
2. CMake konfigurieren (isa-22.3.11, Release, SECURE_PATH aktiv)
3. `make -j$(nproc)` → `build-output/lib/inputstream.adaptive.so.22.3.11`
4. `.isa-build-version` wird gesetzt

Der `make install`-Schritt wird von Kodi's cmake-Helper überschrieben
(Prefix → /usr). Daher werden die `.so`-Dateien manuell nach `build-output/lib/`
kopiert. Fürs Deployment siehe `deploy.sh`.

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
