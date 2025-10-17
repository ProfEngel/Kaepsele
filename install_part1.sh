#!/bin/bash
# ============================================================================
# Käpsele Installation - Teil 1
# Installation bis zum Neustart (NVIDIA-Treiber & CUDA)
# ============================================================================
# Für: Ubuntu 24.04
# Hardware: NVIDIA GPU (z.B. RTX 5060 Ti mit 16GB VRAM)
# ============================================================================

set -e  # Bei Fehler abbrechen

echo "============================================================================"
echo "Käpsele Installation - Teil 1"
echo "Installation bis zum Neustart"
echo "============================================================================"
echo ""

# Farben für Ausgabe
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# 1. System-Updates
# ============================================================================
log_info "Starte System-Updates..."
sudo apt update && sudo apt upgrade -y

# ============================================================================
# 2. Installation von grundlegenden Tools
# ============================================================================
log_info "Installiere grundlegende Tools..."
sudo apt install -y build-essential wget curl git htop net-tools \
    ca-certificates gnupg software-properties-common \
    jq openssl

# ============================================================================
# 3. Miniconda Installation
# ============================================================================
log_info "Installiere Miniconda..."
cd /tmp
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3
rm Miniconda3-latest-Linux-x86_64.sh

# Miniconda initialisieren
$HOME/miniconda3/bin/conda init bash
source ~/.bashrc

log_info "Miniconda Version: $(conda --version)"

# ============================================================================
# 4. NVIDIA-Treiber Installation
# ============================================================================
log_info "Prüfe vorhandene NVIDIA GPU..."
if ! lspci | grep -i nvidia > /dev/null; then
    log_error "Keine NVIDIA GPU gefunden! Installation wird abgebrochen."
    exit 1
fi

log_info "NVIDIA GPU gefunden:"
lspci | grep -i nvidia

log_info "Installiere NVIDIA-Treiber..."
# Verfügbare Treiber anzeigen
ubuntu-drivers devices

# Installation des empfohlenen Treibers (für Ubuntu 24.04)
sudo apt install -y nvidia-driver-550

log_info "NVIDIA-Treiber installiert."

# ============================================================================
# 5. CUDA Toolkit Installation
# ============================================================================
log_info "Installiere CUDA Toolkit 12.6..."
cd /tmp
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-6

# Umgebungsvariablen setzen
log_info "Setze CUDA Umgebungsvariablen..."
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc

# ============================================================================
# Neustart-Hinweis
# ============================================================================
echo ""
echo "============================================================================"
log_info "Teil 1 der Installation ist abgeschlossen!"
echo "============================================================================"
log_warn "WICHTIG: Ein Neustart ist erforderlich, damit der NVIDIA-Treiber aktiv wird."
echo ""
echo "Nach dem Neustart:"
echo "  1. Führen Sie 'nvidia-smi' aus, um die GPU zu überprüfen"
echo "  2. Führen Sie 'nvcc --version' aus, um CUDA zu überprüfen"
echo "  3. Starten Sie dann das zweite Installations-Skript: ./install_part2.sh"
echo ""
log_warn "Möchten Sie JETZT neu starten? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log_info "System wird neu gestartet..."
    sudo reboot
else
    log_info "Bitte starten Sie das System manuell neu und führen Sie dann Teil 2 aus."
fi
