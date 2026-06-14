#!/usr/bin/env bash
# le13-isa-build — Deploy pre-patchte Configs auf crackberry5 LE13
# Führt die fixes aus DRMPRIME-AUS + Crunchyroll-Patch + Player-Override
set -euo pipefail

TARGET="${1:-crackberry5}"

echo "=== Deploy Configs auf $TARGET ==="

# Prüfe Target
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "root@$TARGET" "echo OK" 2>/dev/null; then
    echo "Target $TARGET nicht erreichbar. Configs lokal vorbereitet:"
    echo "  deploy/configs/ ← scp später nach /storage/.kodi/userdata/"
    exit 0
fi

# Kodi stoppen
ssh "root@$TARGET" 'systemctl stop kodi 2>/dev/null; sleep 2; killall kodi.bin 2>/dev/null; sleep 2'

echo "--- 1/4: guisettings.xml (DRMPRIME aus) ---"
ssh "root@$TARGET" << 'GS'
    GS_FILE="/storage/.kodi/userdata/guisettings.xml"
    [ -f "$GS_FILE" ] || { echo "guisettings.xml nicht gefunden, skip"; exit 0; }
    # Backup
    cp "$GS_FILE" "${GS_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    # useprimerenderer: default=false, wert=2 (Pixel Shaders)
    sed -i 's|videoplayer.useprimerenderer" default="true">[01]</setting>|videoplayer.useprimerenderer" default="false">2</setting>|' "$GS_FILE"
    # useprimedecoder: aus
    sed -i 's|videoplayer.useprimedecoder" default="true">true</setting>|videoplayer.useprimedecoder" default="false">false</setting>|' "$GS_FILE"
    sed -i 's|videoplayer.useprimedecoderforhw" default="true">true</setting>|videoplayer.useprimedecoderforhw" default="false">false</setting>|' "$GS_FILE"
    sed -i 's|videoplayer.usemediacodec" default="true">true</setting>|videoplayer.usemediacodec" default="false">false</setting>|' "$GS_FILE"
    sed -i 's|videoplayer.usemediacodecsurface" default="true">true</setting>|videoplayer.usemediacodecsurface" default="false">false</setting>|' "$GS_FILE"
    echo "guisettings.xml: DRMPRIME DISABLED (Pixel Shaders)"
GS

echo "--- 2/4: advancedsettings.xml ---"
cat > /tmp/advancedsettings.xml << 'XML'
<advancedsettings>
  <loglevel>2</loglevel>
  <video>
    <useprimerenderer>2</useprimerenderer>
  </video>
</advancedsettings>
XML
scp /tmp/advancedsettings.xml "root@$TARGET:/storage/.kodi/userdata/advancedsettings.xml"
echo "advancedsettings.xml: Pixel Shaders erzwungen"

echo "--- 3/4: playercorefactory.xml ---"
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
scp /tmp/playercorefactory.xml "root@$TARGET:/storage/.kodi/userdata/playercorefactory.xml"
echo "playercorefactory.xml: VideoPlayer erzwungen"

echo "--- 4/4: Crunchyroll force_secure_decoder entfernen ---"
ssh "root@$TARGET" << 'CR'
    PY_FILE="/storage/.kodi/addons/plugin.video.crunchyroll/resources/lib/videoplayer.py"
    [ -f "$PY_FILE" ] || { echo "videoplayer.py nicht gefunden, skip"; exit 0; }
    cp "$PY_FILE" "${PY_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    sed -i 's/json.dumps({"force_secure_decoder": True})/"{}"/' "$PY_FILE"
    # Caches löschen
    find /storage/.kodi/addons/plugin.video.crunchyroll/ -name '__pycache__' -exec rm -rf {} + 2>/dev/null
    find /storage/.kodi/addons/plugin.video.crunchyroll/ -name '*.pyc' -delete 2>/dev/null
    echo "Crunchyroll: force_secure_decoder entfernt"
CR

echo "--- 5/5: NOSECUREDECODER + ISA-Debug-Logging in ISA-Settings aktivieren ---"
ssh "root@$TARGET" << 'NSD'
    ISA_SETTINGS="/storage/.kodi/addons/inputstream.adaptive/settings.xml"
    if [ -f "$ISA_SETTINGS" ]; then
        cp "$ISA_SETTINGS" "${ISA_SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"
        # NOSECUREDECODER: value 1 = aktiv (default war 0 = false)
        sed -i \
            -e 's|id="NOSECUREDECODER" default="true">0|id="NOSECUREDECODER" default="true">1|' \
            -e 's|id="debug_logging" default="false">0|id="debug_logging" default="false">1|' \
            -e 's|id="PR_LOGGING" default="false">0|id="PR_LOGGING" default="false">1|' \
            "$ISA_SETTINGS"
        echo "NOSECUREDECODER=true, debug_logging=1, PR_LOGGING=1"
    else
        echo "settings.xml nicht gefunden — ISA ggf. nicht installiert"
    fi
NSD

# Kodi starten
ssh "root@$TARGET" 'systemctl start kodi'

echo ""
echo "--- 6/6: Watchdog pausieren + aktualisieren ---"
WDG_INTERVAL=2
ssh "root@$TARGET" << 'WDG'
    AUTO="/storage/.config/autostart.sh"
    if [ -f "$AUTO" ]; then
        cp "$AUTO" "${AUTO}.bak.$(date +%Y%m%d-%H%M%S)"
        echo "Watchdog: $AUTO gefunden, aktualisiere"
    else
        echo "Watchdog: $AUTO nicht gefunden, lege neu an"
    fi

    cat > /tmp/autostart.sh << 'SCRIPT'
#!/bin/sh
# le13-crackberry5 DRMPRIME-Watchdog
# Setzt alle DRMPRIME-Einstellungen zurueck, solange Kodi sie ueberschreibt
INTERVAL=2

/usr/bin/kodi-send --action="Quit" 2>/dev/null
sleep 3

while true; do
    GS="/storage/.kodi/userdata/guisettings.xml"
    ISA="/storage/.kodi/addons/inputstream.adaptive/settings.xml"
    CR="/storage/.kodi/addons/plugin.video.crunchyroll/resources/lib/videoplayer.py"

    # 1. guisettings.xml: Pixel Shaders + SW-Decode
    [ -f "$GS" ] && sed -i \
        -e 's|videoplayer.useprimerenderer" default="true">[01]</setting>|videoplayer.useprimerenderer" default="false">2</setting>|' \
        -e 's|videoplayer.useprimedecoder" default="true">true</setting>|videoplayer.useprimedecoder" default="false">false</setting>|' \
        -e 's|videoplayer.useprimedecoderforhw" default="true">true</setting>|videoplayer.useprimedecoderforhw" default="false">false</setting>|' \
        -e 's|videoplayer.usemediacodec" default="true">true</setting>|videoplayer.usemediacodec" default="false">false</setting>|' \
        -e 's|videoplayer.usemediacodecsurface" default="true">true</setting>|videoplayer.usemediacodecsurface" default="false">false</setting>|' \
        "$GS" 2>/dev/null || true

    # 2. ISA-Settings: NOSECUREDECODER + Debug-Logging
    [ -f "$ISA" ] && sed -i \
        -e 's|id="NOSECUREDECODER" default="true">0|id="NOSECUREDECODER" default="true">1|' \
        -e 's|id="debug_logging" default="false">0|id="debug_logging" default="false">1|' \
        -e 's|id="PR_LOGGING" default="false">0|id="PR_LOGGING" default="false">1|' \
        "$ISA" 2>/dev/null || true

    # 3. Crunchyroll: force_secure_decoder entfernen
    [ -f "$CR" ] && sed -i \
        -e 's/json.dumps({"force_secure_decoder": True})/"{}"/' \
        "$CR" 2>/dev/null || true

    sleep "$INTERVAL"
done
SCRIPT

    cp /tmp/autostart.sh "$AUTO"
    chmod +x "$AUTO"
    echo "Watchdog: aktualisiert"
WDG

echo ""
echo "=== Configs deployt ==="
echo "Nächster Schritt: Vor-Ort Crunchyroll testen"
echo "Verify: ssh $TARGET 'grep LinuxRendererGLES /storage/.kodi/temp/kodi.log | tail -3'"
echo "Watchdog: /storage/.config/autostart.sh läuft (alle ${WDG_INTERVAL}s)"
