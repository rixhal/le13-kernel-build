#!/usr/bin/env bash
# le13-isa-build — Build ISA 22.3.14 from source with SECURE_PATH patch
# Umgewidmet 2026-06-12: vom Kernel-Build auf ISA Source Build
set -euo pipefail

echo "=== le13-isa-build ==="

# Prerequisites
required="cmake g++ git make"
missing=""
for cmd in $required; do
    if ! command -v "$cmd" &>/dev/null; then
        missing="$missing $cmd"
    fi
done
if [ -n "$missing" ]; then
    echo "Fehlende Pakete:$missing"
    echo "Installiere: sudo apt install$missing"
    # shellcheck disable=SC2086 # intentional word-splitting for package list
    sudo apt install -y $missing
fi

# pugixml build (static, da auf LE13 nicht vorhanden)
if [ ! -f "deps/pugixml/libpugixml.a" ]; then
    echo "=== Baue pugixml (static) ==="
    mkdir -p deps
    if [ ! -d "deps/pugixml" ]; then
        git clone --depth 1 https://github.com/zeux/pugixml.git deps/pugixml
    fi
    cd deps/pugixml
    g++ -c -fPIC -O2 -I src src/pugixml.cpp
    ar rcs libpugixml.a pugixml.o
    rm -f pugixml.o
    cd ../..
    echo "pugixml static: OK"
fi

# ISA Source verwenden
ISA_DIR="isa-22.3.11"
if [ ! -d "$ISA_DIR" ]; then
    echo "=== ISA $ISA_DIR nicht gefunden — Fallback: Nexus Branch klonen ==="
    ISA_DIR="inputstream.adaptive"
    if [ ! -d "$ISA_DIR" ]; then
        git clone --branch Nexus --depth 1 https://github.com/xbmc/inputstream.adaptive.git "$ISA_DIR"
    fi
fi

# Patch anwenden (SECURE_PATH in GetCapabilities)
PATCH_FILE="config/secure-path.patch"
if [ -f "$PATCH_FILE" ]; then
    cd "$ISA_DIR"
    if ! patch -p1 --dry-run < "../$PATCH_FILE" 2>/dev/null; then
        echo "Patch bereits angewendet oder nicht anwendbar"
    else
        echo "=== Wende SECURE_PATH-Patch an ==="
        patch -p1 < "../$PATCH_FILE"
    fi
    cd ..
fi

# Build
echo "=== CMake konfigurieren ==="
mkdir -p "$ISA_DIR/build"
cd "$ISA_DIR/build"

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DENABLE_PUGIXML_STATIC=ON \
    -DPUGIXML_INCLUDE_DIR=../../deps/pugixml/src \
    -DPUGIXML_LIBRARIES=../../deps/pugixml/libpugixml.a \
    -DCMAKE_INSTALL_PREFIX=../../build-output

echo "=== Build ISA ==="
make -j"$(nproc)"

echo "=== Install ==="
make install

cd ../..

echo ""
echo "=== Build abgeschlossen ==="
echo "ISA .so: build-output/lib/inputstream.adaptive.so*"
ls -la build-output/lib/inputstream.adaptive.so* 2>/dev/null || echo "WARN: Keine .so gefunden"

# Version-Tracker
COMMIT_HASH=$(cd "$ISA_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo "$COMMIT_HASH" > .isa-build-version
echo "Version: $COMMIT_HASH"
