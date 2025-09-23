#!/bin/bash
# ==============================================================================
# https://claude.ai/chat/c675bda1-47cd-4f01-b8e4-060549e20dc8
# Setup-Skript für Kaepsele OpenWebUI Server
# Ubuntu 22.04 LTS mit NVIDIA GPU(s)
# Version: 1.0
# ==============================================================================

set -e  # Bei Fehlern abbrechen

# Farben für Ausgaben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging-Funktion
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# ==============================================================================
# KONFIGURATION
# ==============================================================================

# Server-IP automatisch ermitteln (oder manuell setzen)
SERVER_IP=$(hostname -I | awk '{print $1}')
log "Server IP: $SERVER_IP"

# API-Schlüssel (ändern Sie diese!)
VLLM_API_KEY="sk-$(openssl rand -hex 16)"
SEARXNG_SECRET_KEY=$(openssl rand -hex 32)

# Modellpfade
MODEL_DIR="/root/modelle"
DOCKER_DIR="/root/docker"

# GPU-Anforderungen prüfen
check_gpu_requirements() {
    local total_vram=0
    while read -r line; do
        if [[ $line =~ ([0-9]+)MiB ]]; then
            total_vram=$((total_vram + ${BASH_REMATCH[1]}))
        fi
    done < <(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
    
    log "Gesamt verfügbarer VRAM: ${total_vram} MiB"
    
    # GPT-OSS 20B benötigt mindestens 40GB VRAM (40960 MiB)
    if [ $total_vram -lt 40960 ]; then
        warning "GPT-OSS 20B benötigt mindestens 40GB VRAM. Gefunden: ${total_vram} MiB"
        warning "Das Modell wird trotzdem geladen, aber Performance könnte beeinträchtigt sein."
        warning "Erwägen Sie die Verwendung von Quantisierung oder mehreren GPUs."
    fi
}

# ==============================================================================
# SCHRITT 1: System-Updates und Basis-Tools
# ==============================================================================

log "Installiere System-Updates und Basis-Tools..."

apt update && apt upgrade -y
apt install -y \
    build-essential \
    wget \
    curl \
    git \
    htop \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    nano \
    vim

# ==============================================================================
# SCHRITT 2: NVIDIA-Treiber und CUDA
# ==============================================================================

log "Installiere NVIDIA-Treiber..."

# Alte Treiber entfernen
apt remove --purge -y nvidia-* cuda-* 2>/dev/null || true
apt autoremove -y

# NVIDIA-Treiber installieren (Standard-Treiber aus Ubuntu-Repository)
apt install -y nvidia-driver-535-server
apt install -y nvidia-utils-535-server

log "Installiere CUDA Toolkit..."

# CUDA Repository hinzufügen
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update
apt-get -y install cuda-toolkit-12-3

# Umgebungsvariablen setzen
cat >> ~/.bashrc << 'EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF

source ~/.bashrc

# ==============================================================================
# SCHRITT 3: Docker und NVIDIA Container Toolkit
# ==============================================================================

log "Installiere Docker..."

# Docker GPG-Schlüssel hinzufügen
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Docker Repository hinzufügen
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Docker starten
systemctl start docker
systemctl enable docker

log "Installiere NVIDIA Container Toolkit..."

# NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y nvidia-container-toolkit

# Docker für NVIDIA konfigurieren
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# ==============================================================================
# SCHRITT 4: Ollama Installation
# ==============================================================================

log "Installiere Ollama..."

curl -fsSL https://ollama.com/install.sh | sh

# Ollama Service konfigurieren
cat > /etc/systemd/system/ollama.service << EOF
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_MAX_LOADED_MODELS=2"
Environment="OLLAMA_NUM_PARALLEL=8"
Environment="OLLAMA_KEEP_ALIVE=-1"
Environment="OLLAMA_MAX_QUEUE=256"

[Install]
WantedBy=default.target
EOF

systemctl daemon-reload
systemctl enable ollama
systemctl start ollama

# Warte auf Ollama-Start
sleep 10

# Embedding-Modell herunterladen
log "Lade Ollama Embedding-Modell..."
ollama pull jeffh/intfloat-multilingual-e5-large:q8_0

# ==============================================================================
# SCHRITT 5: vLLM für GPT-OSS 20B
# ==============================================================================

log "Starte vLLM Container für GPT-OSS 20B..."

# GPU-Anforderungen prüfen
check_gpu_requirements

# Cache-Verzeichnis erstellen
mkdir -p /root/.cache/huggingface

# vLLM Container starten (angepasst für Multi-GPU)
# Ermittle Anzahl der GPUs
GPU_COUNT=$(nvidia-smi -L | wc -l)
log "Gefundene GPUs: $GPU_COUNT"

# Tensor Parallel Size basierend auf GPU-Anzahl
# GPT-OSS 20B benötigt mindestens 2 GPUs für optimale Performance
TP_SIZE=1
if [ $GPU_COUNT -ge 2 ]; then
    TP_SIZE=2
fi
if [ $GPU_COUNT -ge 4 ]; then
    TP_SIZE=4
fi

# Pipeline Parallel Size für bessere Speicherverteilung bei 20B Modell
PP_SIZE=1
if [ $GPU_COUNT -ge 4 ]; then
    PP_SIZE=2
    TP_SIZE=2
fi

log "Konfiguration: Tensor Parallel=$TP_SIZE, Pipeline Parallel=$PP_SIZE"

# vLLM mit GPT-OSS 20B starten
# Das Modell benötigt ca. 40-50GB VRAM (mit Quantisierung weniger)
docker run -d \
    --gpus all \
    --restart unless-stopped \
    --ipc=host \
    --shm-size=16g \
    -p 8000:8000 \
    -v /root/.cache/huggingface:/root/.cache/huggingface \
    -e HF_HUB_ENABLE_HF_TRANSFER=1 \
    -e CUDA_VISIBLE_DEVICES=all \
    --name vllm_gpt_oss \
    vllm/vllm-openai:latest \
    --model vllm/gpt-oss-20b \
    --dtype auto \
    --max-model-len 16384 \
    --port 8000 \
    --api-key "$VLLM_API_KEY" \
    --tensor-parallel-size $TP_SIZE \
    --pipeline-parallel-size $PP_SIZE \
    --gpu-memory-utilization 0.90 \
    --max-num-seqs 8 \
    --max-num-batched-tokens 32768 \
    --enable-prefix-caching \
    --disable-log-stats

# ALTERNATIVE: Mit AWQ 4-bit Quantisierung für weniger VRAM-Verbrauch
# Kommentieren Sie die obige docker run Zeile aus und nutzen Sie diese:
# docker run -d \
#     --gpus all \
#     --restart unless-stopped \
#     --ipc=host \
#     --shm-size=16g \
#     -p 8000:8000 \
#     -v /root/.cache/huggingface:/root/.cache/huggingface \
#     -e HF_HUB_ENABLE_HF_TRANSFER=1 \
#     --name vllm_gpt_oss \
#     vllm/vllm-openai:latest \
#     --model vllm/gpt-oss-20b \
#     --quantization awq \
#     --dtype half \
#     --max-model-len 8192 \
#     --port 8000 \
#     --api-key "$VLLM_API_KEY" \
#     --tensor-parallel-size $TP_SIZE \
#     --gpu-memory-utilization 0.95

log "vLLM API Key: $VLLM_API_KEY"

# Warte auf vLLM Start
log "Warte auf vLLM Start (kann einige Minuten dauern bei 20B Modell)..."
sleep 30

# ==============================================================================
# SCHRITT 6: SearXNG einrichten
# ==============================================================================

log "Richte SearXNG ein..."

# SearXNG-Verzeichnis erstellen
mkdir -p $DOCKER_DIR/searxng

# SearXNG settings.yml erstellen
cat > $DOCKER_DIR/searxng/settings.yml << EOF
use_default_settings: true

server:
  secret_key: "$SEARXNG_SECRET_KEY"
  limiter: false
  image_proxy: true
  port: 8080
  bind_address: "0.0.0.0"

ui:
  static_use_hash: true

search:
  safe_search: 0
  autocomplete: "google"
  default_lang: "de"
  formats:
    - html
    - json

engines:
  - name: google
    engine: google
    shortcut: g
    
  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg
    
  - name: wikipedia
    engine: wikipedia
    shortcut: wp
    base_url: 'https://de.wikipedia.org/'
    
  - name: wikidata
    engine: wikidata
    shortcut: wd
EOF

# SearXNG Container starten
docker run -d \
    --name searxng \
    --restart unless-stopped \
    -e SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml \
    -v $DOCKER_DIR/searxng/settings.yml:/etc/searxng/settings.yml:ro \
    -p 4000:8080 \
    searxng/searxng

# ==============================================================================
# SCHRITT 7: OpenWebUI installieren
# ==============================================================================

log "Installiere OpenWebUI..."

# OpenWebUI mit Code-Interpreter
docker run -d \
    -p 80:8080 \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    -v open-webui:/app/backend/data \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --add-host=host.docker.internal:host-gateway \
    --name open-webui \
    --restart always \
    ghcr.io/open-webui/open-webui:main

# ==============================================================================
# SCHRITT 8: Konfigurationsdatei erstellen
# ==============================================================================

log "Erstelle Konfigurationsdatei..."

cat > ~/kaepsele_config.txt << EOF
==============================================================================
KAEPSELE OPENWEBUI SERVER - KONFIGURATION
==============================================================================

Server IP: $SERVER_IP

ZUGANGSDATEN:
-------------
OpenWebUI: http://$SERVER_IP
vLLM API Key: $VLLM_API_KEY

DIENSTE:
--------
- OpenWebUI: http://$SERVER_IP (Port 80)
- vLLM API: http://$SERVER_IP:8000
- Ollama API: http://$SERVER_IP:11434
- SearXNG: http://$SERVER_IP:4000

OPENWEBUI EINSTELLUNGEN:
-----------------------
1. Besuchen Sie http://$SERVER_IP und erstellen Sie einen Admin-Account

2. Navigieren Sie zu: Administrationsbereich > Einstellungen > Verbindungen
   
   OpenAI-kompatible API (vLLM):
   - URL: http://$SERVER_IP:8000/v1
   - API Key: $VLLM_API_KEY
   
   Ollama:
   - URL: http://host.docker.internal:11434

3. Navigieren Sie zu: Administrationsbereich > Einstellungen > Dokumente
   - Embedding-Modell-Engine: Ollama
   - URL: http://host.docker.internal:11434
   - Embedding-Modell: jeffh/intfloat-multilingual-e5-large:q8_0

4. Navigieren Sie zu: Administrationsbereich > Einstellungen > Web Search
   - Websuche aktivieren: Ja
   - Suchmaschine: SearxNG
   - SearxNG-Abfrage-URL: http://$SERVER_IP:4000/search?q=<query>

MODELLE:
--------
- LLM: GPT-OSS 20B (vllm/gpt-oss-20b) via vLLM
  * 20 Milliarden Parameter
  * Optimiert für vLLM Performance
  * Kontext: 16384 Token
- Embedding: jeffh/intfloat-multilingual-e5-large:q8_0 (via Ollama)

NÜTZLICHE BEFEHLE:
-----------------
# Container-Status prüfen
docker ps

# Logs anzeigen
docker logs open-webui
docker logs vllm_gpt_oss
docker logs searxng

# GPU-Status
nvidia-smi

# Ollama-Modelle anzeigen
ollama list

# Container neustarten
docker restart open-webui
docker restart vllm_gpt_oss
docker restart searxng

==============================================================================
EOF

# ==============================================================================
# SCHRITT 9: Firewall-Regeln (optional)
# ==============================================================================

log "Konfiguriere Firewall..."

# UFW installieren falls nicht vorhanden
apt install -y ufw

# Firewall-Regeln
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # OpenWebUI
ufw allow 8000/tcp  # vLLM
ufw allow 11434/tcp # Ollama
ufw allow 4000/tcp  # SearXNG

# Firewall aktivieren (Vorsicht bei SSH-Verbindungen!)
# ufw --force enable

# ==============================================================================
# ABSCHLUSS
# ==============================================================================

log "===================================================================="
log "Installation abgeschlossen!"
log "===================================================================="
log ""
log "Konfigurationsdatei gespeichert unter: ~/kaepsele_config.txt"
log ""
log "OpenWebUI ist erreichbar unter: http://$SERVER_IP"
log ""
log "WICHTIG: System-Neustart erforderlich für NVIDIA-Treiber!"
log "Führen Sie aus: sudo reboot"
log ""
log "Nach dem Neustart:"
log "1. Prüfen Sie GPU-Status mit: nvidia-smi"
log "2. Prüfen Sie Container mit: docker ps"
log "3. Konfigurieren Sie OpenWebUI gemäß ~/kaepsele_config.txt"
log ""
log "Bei VRAM-Problemen mit GPT-OSS 20B:"
log "- Option 1: Verwenden Sie --quantization awq für 4-bit Quantisierung"
log "- Option 2: Erhöhen Sie die Anzahl der GPUs"
log "- Option 3: Reduzieren Sie --max-model-len auf 8192 oder 4096"
log "===================================================================="

# Frage nach Neustart
read -p "Möchten Sie das System jetzt neu starten? (j/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Jj]$ ]]; then
    log "System wird neu gestartet..."
    reboot
fi
