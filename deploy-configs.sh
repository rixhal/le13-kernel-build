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

echo "--- 5/5: NOSECUREDECODER in ISA-Settings aktivieren ---"
ssh "root@$TARGET" << 'NSD'
    ISA_SETTINGS="/storage/.kodi/addons/inputstream.adaptive/settings.xml"
    if [ -f "$ISA_SETTINGS" ]; then
        cp "$ISA_SETTINGS" "${ISA_SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"
        # NOSECUREDECODER: value 1 = aktiv (default war 0 = false)
        sed -i 's|id="NOSECUREDECODER" default="true">0|id="NOSECUREDECODER" default="true">1|' "$ISA_SETTINGS"
        echo "NOSECUREDECODER auf true gesetzt"
    else
        echo "settings.xml nicht gefunden — ISA ggf. nicht installiert"
    fi
NSD

# Kodi starten
ssh "root@$TARGET" 'systemctl start kodi'

echo ""
echo "=== Configs deployt ==="
echo "Nächster Schritt: Vor-Ort Crunchyroll testen"
echo "Verify: ssh $TARGET 'grep LinuxRendererGLES /storage/.kodi/temp/kodi.log | tail -3'"
