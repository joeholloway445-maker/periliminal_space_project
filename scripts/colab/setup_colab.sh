#!/bin/bash
# setup_colab.sh - One-click Colab environment for Periliminal.Space
# Run this as the first cell in any Colab notebook:
#   !bash scripts/colab/setup_colab.sh
set -euo pipefail

echo "=== Setting up Colab environment for Periliminal.Space ==="

# ---- System deps ----
apt-get update -qq
apt-get install -y -qq unzip wget curl git-lfs 2>/dev/null || true

# ---- Godot headless ----
GODOT_VER="4.3"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/Godot_v${GODOT_VER}-stable_linux.x86_64.zip"

if ! command -v godot &> /dev/null; then
    echo "Downloading Godot ${GODOT_VER} headless..."
    wget -q "${GODOT_URL}" -O /tmp/godot.zip
    unzip -qo /tmp/godot.zip -d /tmp/godot
    cp /tmp/godot/Godot_v${GODOT_VER}-stable_linux.x86_64 /usr/local/bin/godot
    chmod +x /usr/local/bin/godot
    echo "Godot installed: $(godot --version 2>&1 | head -1)"
else
    echo "Godot already installed: $(godot --version 2>&1 | head -1)"
fi

# ---- Export templates (needed for export) ----
TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VER}.stable"
if [ ! -d "${TEMPLATES_DIR}" ]; then
    echo "Downloading export templates..."
    TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/Godot_v${GODOT_VER}-stable_export_templates.tpz"
    wget -q "${TEMPLATES_URL}" -O /tmp/templates.tpz
    mkdir -p "${TEMPLATES_DIR}"
    unzip -qo /tmp/templates.tpz -d "${TEMPLATES_DIR}"
    echo "Export templates installed."
else
    echo "Export templates already present."
fi

# ---- Python deps ----
pip install -q gdown Pillow 2>/dev/null || true

# ---- Clone repo (if not already present) ----
if [ ! -d "CATSINO.CASINO" ]; then
    echo "Cloning CATSINO.CASINO..."
    git clone https://github.com/joeholloway445-maker/CATSINO.CASINO.git
else
    echo "Repo already cloned. Pulling latest..."
    cd CATSINO.CASINO && git pull && cd ..
fi

# ---- Verify ----
echo ""
echo "=== Environment ready ==="
echo "Godot:        $(godot --version 2>&1 | head -1 || echo 'NOT FOUND')"
echo "Python:       $(python --version 2>&1)"
echo "Project:      $(ls CATSINO.CASINO/godot/project.godot 2>/dev/null && echo 'OK' || echo 'MISSING')"
echo "Templates:    $(ls ${TEMPLATES_DIR}/linux_* 2>/dev/null | wc -l) files"
echo ""
echo "Ready to import godot_runner and run pipelines."
