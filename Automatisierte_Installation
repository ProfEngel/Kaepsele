# Master-Installation Käpsele: Zweiteilige Installation

Ich erstelle dir zwei umfassende Shell-Skripte für die automatisierte Installation. Hier sind beide komplett:

---

## Teil 1: Installation bis zum Neustart

```bash
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
```

---

## Teil 2: Hauptinstallation nach Neustart

```bash
#!/bin/bash
# ============================================================================
# Käpsele Installation - Teil 2
# Hauptinstallation nach Neustart
# ============================================================================
# Für: Ubuntu 24.04
# Hardware: NVIDIA GPU (z.B. RTX 5060 Ti mit 16GB VRAM)
# ============================================================================

set -e  # Bei Fehler abbrechen

# Farben für Ausgabe
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

log_credential() {
    echo -e "${BLUE}[CREDENTIAL]${NC} $1"
}

echo "============================================================================"
echo "Käpsele Installation - Teil 2"
echo "Hauptinstallation nach Neustart"
echo "============================================================================"
echo ""

# ============================================================================
# WICHTIG: GPU & CUDA Überprüfung
# ============================================================================
log_info "Überprüfe NVIDIA-Treiber..."
if ! command -v nvidia-smi &> /dev/null; then
    log_error "nvidia-smi nicht gefunden! Bitte stellen Sie sicher, dass Teil 1 abgeschlossen und das System neu gestartet wurde."
    exit 1
fi

nvidia-smi
echo ""

log_info "Überprüfe CUDA-Installation..."
if ! command -v nvcc &> /dev/null; then
    log_error "nvcc nicht gefunden! CUDA-Toolkit nicht korrekt installiert."
    exit 1
fi

source ~/.bashrc
nvcc --version
echo ""

# ============================================================================
# CREDENTIAL-GENERIERUNG
# ============================================================================
log_info "Generiere sichere Credentials..."
echo ""

# Credentials generieren
JUPYTER_TOKEN=$(openssl rand -hex 32)
PIPELINE_API_KEY=$(openssl rand -hex 24)
VLLM_API_KEY="sk-$(openssl rand -hex 32)"
SEARXNG_SECRET=$(openssl rand -hex 32)

# Credentials-Datei erstellen
CREDENTIALS_FILE="$HOME/kaepsele_credentials.txt"
cat > "$CREDENTIALS_FILE" << EOF
============================================================================
Käpsele Installation - Credentials
Erstellt am: $(date)
============================================================================

WICHTIG: Bewahren Sie diese Datei sicher auf!
Diese Credentials werden für die Konfiguration der Services benötigt.

----------------------------------------------------------------------------
Jupyter Code-Interpreter
----------------------------------------------------------------------------
Token: ${JUPYTER_TOKEN}
URL: http://localhost:8888
Verwendung: Admin > Einstellungen > Code Execution
  - Execution Backend: Jupyter
  - Jupyter Base URL: http://host.docker.internal:8888
  - Jupyter Token: ${JUPYTER_TOKEN}

----------------------------------------------------------------------------
OpenWebUI Pipelines
----------------------------------------------------------------------------
API-Schlüssel: ${PIPELINE_API_KEY}
Verwendung: Admin > Einstellungen > Verbindungen
  - API-URL: http://host.docker.internal:9099
  - API-Schlüssel: ${PIPELINE_API_KEY}

----------------------------------------------------------------------------
vLLM Sprachmodell
----------------------------------------------------------------------------
API-Schlüssel: ${VLLM_API_KEY}
URL: http://localhost:8000/v1
Verwendung: Admin > Einstellungen > Verbindungen (OpenAI API)
  - URL: http://host.docker.internal:8000/v1
  - API-Schlüssel: ${VLLM_API_KEY}

----------------------------------------------------------------------------
SearXNG Metasuchmaschine
----------------------------------------------------------------------------
Secret Key: ${SEARXNG_SECRET}
URL: http://localhost:4000
Verwendung: Admin > Einstellungen > Web Search
  - Query URL: http://host.docker.internal:4000/search?q=<query>

----------------------------------------------------------------------------
Ollama
----------------------------------------------------------------------------
URL: http://localhost:11434
Verwendung: 
  - Admin > Einstellungen > Verbindungen > Ollama URL
  - Admin > Einstellungen > Dokumente > Embedding URL

============================================================================
EOF

# Credentials anzeigen
echo ""
log_info "==================================================================="
log_info "WICHTIG: Credentials wurden generiert!"
log_info "==================================================================="
echo ""
cat "$CREDENTIALS_FILE"
echo ""
log_credential "Credentials wurden gespeichert in: $CREDENTIALS_FILE"
log_warn "Bitte notieren oder ausdrucken Sie diese Credentials!"
echo ""
read -p "Drücken Sie Enter, um fortzufahren..."
echo ""

# ============================================================================
# MODELL-AUSWAHL
# ============================================================================
log_info "==================================================================="
log_info "Modell-Auswahl für vLLM"
log_info "==================================================================="
echo ""
echo "Welches Qwen3-Modell möchten Sie verwenden?"
echo ""
echo "1) Qwen3-4B-Instruct (empfohlen für kleine GPUs / 16GB VRAM)"
echo "   - Schnell, effizient, geringer VRAM-Verbrauch"
echo "   - VRAM: ~6-8 GB"
echo ""
echo "2) Qwen3-30B-A3B-Instruct-2507 (für High-End GPUs)"
echo "   - Höchste Qualität, aber hoher VRAM-Verbrauch"
echo "   - VRAM: ~30-40 GB (NICHT für 16GB GPUs!)"
echo ""
read -p "Ihre Wahl (1 oder 2): " model_choice

case $model_choice in
    1)
        VLLM_MODEL="Qwen/Qwen3-4B-Instruct-2507"
        MAX_MODEL_LEN="32768"
        GPU_MEMORY_UTIL="0.95"
        MAX_NUM_SEQS="8"
        log_info "Gewählt: Qwen/Qwen3-4B-Instruct-2507 (optimiert für 16GB VRAM)"
        ;;
    2)
        VLLM_MODEL="Qwen/Qwen3-30B-A3B-Instruct-2507"
        MAX_MODEL_LEN="262144"
        GPU_MEMORY_UTIL="0.90"
        MAX_NUM_SEQS="4"
        log_warn "WARNUNG: Dieses Modell benötigt >30GB VRAM!"
        log_warn "Für RTX 5060 Ti (16GB) wird dies NICHT funktionieren!"
        read -p "Trotzdem fortfahren? (y/n): " continue_choice
        if [[ ! "$continue_choice" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            log_info "Installation abgebrochen. Bitte starten Sie das Skript erneut."
            exit 0
        fi
        ;;
    *)
        log_error "Ungültige Auswahl. Installation wird abgebrochen."
        exit 1
        ;;
esac

echo ""
log_info "Ausgewähltes Modell: $VLLM_MODEL"
echo ""

# ============================================================================
# DOCKER INSTALLATION
# ============================================================================
log_info "Installiere Docker..."

# Docker GPG-Schlüssel hinzufügen
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Docker Repository hinzufügen
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker installieren
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker-Service starten
sudo systemctl start docker
sudo systemctl enable docker

# Benutzer zur Docker-Gruppe hinzufügen
sudo usermod -aG docker $USER

log_info "Docker installiert: $(docker --version)"

# ============================================================================
# NVIDIA CONTAINER TOOLKIT
# ============================================================================
log_info "Installiere NVIDIA Container Toolkit..."

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Docker mit GPU testen
log_info "Teste Docker mit GPU..."
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi

echo ""
log_info "Docker und NVIDIA Container Toolkit erfolgreich installiert!"
echo ""

# ============================================================================
# OPENWEBUI INSTALLATION
# ============================================================================
log_info "Installiere OpenWebUI..."

docker run -d \
  -p 80:8080 \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -v open-webui:/app/backend/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --add-host=host.docker.internal:host-gateway \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main

log_info "OpenWebUI gestartet auf Port 80"

# ============================================================================
# JUPYTER CODE-INTERPRETER
# ============================================================================
log_info "Installiere Jupyter Code-Interpreter..."

docker run -d \
  -p 8888:8888 \
  --name jupyter-interpreter \
  --restart always \
  jupyter/datascience-notebook \
  start.sh jupyter notebook \
  --NotebookApp.token="${JUPYTER_TOKEN}" \
  --NotebookApp.password='' \
  --NotebookApp.allow_origin='*' \
  --NotebookApp.disable_check_xsrf=True

# Bibliotheken installieren
log_info "Installiere Python-Bibliotheken für Jupyter..."

cat > /tmp/requirements.txt << 'EOF'
pandas
numpy
scipy
matplotlib
seaborn
scikit-learn
statsmodels
pypdf
python-docx
openpyxl
XlsxWriter
xlrd
xlwt
reportlab
python-pptx
PyPDF2
pillow
pdf2image
sympy
requests
beautifulsoup4
qrcode
plotly
streamlit
EOF

docker cp /tmp/requirements.txt jupyter-interpreter:/tmp/requirements.txt
docker exec jupyter-interpreter pip install -r /tmp/requirements.txt

log_info "Jupyter Code-Interpreter konfiguriert"

# ============================================================================
# OPENWEBUI PIPELINES
# ============================================================================
log_info "Installiere OpenWebUI Pipelines..."

docker run -d \
  -p 9099:9099 \
  --add-host=host.docker.internal:host-gateway \
  -v pipelines:/app/pipelines \
  --name pipelines \
  --restart always \
  ghcr.io/open-webui/pipelines:main

log_info "Pipelines gestartet auf Port 9099"

# ============================================================================
# OLLAMA INSTALLATION
# ============================================================================
log_info "Installiere Ollama..."

curl -fsSL https://ollama.com/install.sh | sh

# Ollama-Service konfigurieren
log_info "Konfiguriere Ollama-Service..."

sudo tee /etc/systemd/system/ollama.service > /dev/null << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=/usr/local/cuda/bin:/usr/local/bin:/usr/bin:/bin"
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_MAX_LOADED_MODELS=2"
Environment="OLLAMA_NUM_PARALLEL=2"
Environment="OLLAMA_KEEP_ALIVE=-1"
Environment="OLLAMA_MAX_QUEUE=256"

[Install]
WantedBy=default.target
EOF

# Service neu laden und starten
sudo systemctl daemon-reload
sudo systemctl restart ollama
sudo systemctl enable ollama

# Warten bis Ollama bereit ist
log_info "Warte auf Ollama-Service..."
sleep 5

# ============================================================================
# EMBEDDING-MODELL INSTALLATION
# ============================================================================
log_info "Installiere Embedding-Modell..."

ollama pull jeffh/intfloat-multilingual-e5-large:q8_0

log_info "Embedding-Modell installiert"

# ============================================================================
# VLLM INSTALLATION
# ============================================================================
log_info "Installiere vLLM..."

# Cache-Verzeichnis erstellen
mkdir -p $HOME/.cache/huggingface

log_info "Starte vLLM mit Modell: $VLLM_MODEL"

docker run -d \
  --gpus all \
  --shm-size 16g \
  --restart unless-stopped \
  -p 8000:8000 \
  -v $HOME/.cache/huggingface:/root/.cache/huggingface \
  -e HF_HUB_ENABLE_HF_TRANSFER=1 \
  --name vllm-model \
  vllm/vllm-openai:latest \
  --model "$VLLM_MODEL" \
  --max-model-len "$MAX_MODEL_LEN" \
  --port 8000 \
  --api-key "$VLLM_API_KEY" \
  --max-num-seqs "$MAX_NUM_SEQS" \
  --gpu-memory-utilization "$GPU_MEMORY_UTIL"

log_info "vLLM wird gestartet (Download kann einige Minuten dauern)..."
log_info "Fortschritt verfolgen mit: docker logs -f vllm-model"

# ============================================================================
# SEARXNG INSTALLATION
# ============================================================================
log_info "Installiere SearXNG..."

# Konfigurationsverzeichnis erstellen
mkdir -p $HOME/docker/searxng

# Konfigurationsdatei erstellen
cat > $HOME/docker/searxng/settings.yml << EOF
use_default_settings: true

server:
  secret_key: "${SEARXNG_SECRET}"
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
EOF

# SearXNG Container starten
docker run -d \
  --name searxng \
  -e BASE_URL=http://localhost:4000 \
  -e SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml \
  -v $HOME/docker/searxng/settings.yml:/etc/searxng/settings.yml \
  -p 4000:8080 \
  --restart always \
  searxng/searxng

log_info "SearXNG gestartet auf Port 4000"

# ============================================================================
# INSTALLATIONS-ABSCHLUSS
# ============================================================================
echo ""
echo "============================================================================"
log_info "Installation abgeschlossen!"
echo "============================================================================"
echo ""
log_info "Alle Services sind gestartet. Bitte warten Sie einige Minuten,"
log_info "bis alle Container vollständig hochgefahren sind."
echo ""

# Container-Status anzeigen
log_info "Container-Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# ============================================================================
# ZUGRIFFS-INFORMATIONEN
# ============================================================================
log_info "==================================================================="
log_info "Zugriffs-URLs:"
log_info "==================================================================="
echo ""
echo "OpenWebUI:           http://localhost (oder http://$(hostname -I | awk '{print $1}'))"
echo "Jupyter Notebook:    http://localhost:8888"
echo "SearXNG:             http://localhost:4000"
echo "Ollama API:          http://localhost:11434"
echo "vLLM API:            http://localhost:8000/v1"
echo "Pipelines API:       http://localhost:9099"
echo ""

# ============================================================================
# KONFIGURATIONSANLEITUNG
# ============================================================================
log_info "==================================================================="
log_info "Nächste Schritte - OpenWebUI Konfiguration:"
log_info "==================================================================="
echo ""
echo "1. Öffnen Sie OpenWebUI: http://localhost"
echo "2. Erstellen Sie einen Admin-Account"
echo ""
echo "3. Navigieren Sie zu: Admin > Einstellungen > Verbindungen"
echo "   - Fügen Sie OpenAI API hinzu:"
echo "     • URL: http://host.docker.internal:8000/v1"
echo "     • API-Schlüssel: $VLLM_API_KEY"
echo ""
echo "   - Fügen Sie Ollama hinzu:"
echo "     • URL: http://host.docker.internal:11434"
echo ""
echo "   - Fügen Sie Pipelines hinzu:"
echo "     • API-URL: http://host.docker.internal:9099"
echo "     • API-Schlüssel: $PIPELINE_API_KEY"
echo ""
echo "4. Navigieren Sie zu: Admin > Einstellungen > Dokumente"
echo "   - Embedding-Modell-Engine: Ollama"
echo "   - URL: http://host.docker.internal:11434"
echo "   - Embedding-Modell: jeffh/intfloat-multilingual-e5-large:q8_0"
echo "   - Stapelgröße: 16"
echo "   - Top K: 5"
echo "   - Blockgröße: 800"
echo "   - Blocküberlappung: 100"
echo ""
echo "5. Navigieren Sie zu: Admin > Einstellungen > Code Execution"
echo "   - Execution Backend: Jupyter"
echo "   - Jupyter Base URL: http://host.docker.internal:8888"
echo "   - Jupyter Token: $JUPYTER_TOKEN"
echo ""
echo "6. Navigieren Sie zu: Admin > Einstellungen > Web Search"
echo "   - Websuche aktivieren: Ja"
echo "   - Suchmaschine: SearxNG"
echo "   - Query URL: http://host.docker.internal:4000/search?q=<query>"
echo "   - Ergebnisse: 5"
echo "   - Gleichzeitige Anfragen: 10"
echo ""

# ============================================================================
# CREDENTIAL-DATEI HINWEIS
# ============================================================================
log_credential "==================================================================="
log_credential "WICHTIG: Ihre Credentials"
log_credential "==================================================================="
echo ""
log_credential "Alle Credentials wurden gespeichert in:"
log_credential "$CREDENTIALS_FILE"
echo ""
log_warn "Bitte bewahren Sie diese Datei sicher auf!"
log_warn "Sie benötigen diese Credentials für die OpenWebUI-Konfiguration."
echo ""

# Credential-Datei zum Credentials-Ordner hinzufügen
echo "vLLM_MODEL=${VLLM_MODEL}" >> "$CREDENTIALS_FILE"
echo "MAX_MODEL_LEN=${MAX_MODEL_LEN}" >> "$CREDENTIALS_FILE"

# ============================================================================
# NÜTZLICHE BEFEHLE
# ============================================================================
log_info "==================================================================="
log_info "Nützliche Befehle:"
log_info "==================================================================="
echo ""
echo "Container-Status prüfen:     docker ps"
echo "Container-Logs anzeigen:     docker logs -f <container-name>"
echo "GPU-Auslastung prüfen:       nvidia-smi"
echo "Ollama-Modelle anzeigen:     ollama list"
echo "vLLM-Logs anzeigen:          docker logs -f vllm-model"
echo ""
echo "Container neu starten:"
echo "  docker restart open-webui"
echo "  docker restart vllm-model"
echo "  docker restart jupyter-interpreter"
echo "  docker restart searxng"
echo "  docker restart pipelines"
echo ""
echo "Ollama neu starten:"
echo "  sudo systemctl restart ollama"
echo ""

# ============================================================================
# ABSCHLUSS
# ============================================================================
echo ""
log_info "==================================================================="
log_info "Installation erfolgreich abgeschlossen!"
log_info "==================================================================="
echo ""
log_info "Viel Erfolg mit Ihrem Käpsele-System!"
echo ""
```

---

## Verwendung der Skripte

### 1. Skripte speichern und ausführbar machen

```bash
# Skripte erstellen
nano install_part1.sh
# (Inhalt von Teil 1 einfügen)

nano install_part2.sh
# (Inhalt von Teil 2 einfügen)

# Ausführbar machen
chmod +x install_part1.sh
chmod +x install_part2.sh
```

### 2. Teil 1 ausführen

```bash
./install_part1.sh
```

Nach dem Neustart:

```bash
# GPU prüfen
nvidia-smi

# CUDA prüfen
nvcc --version
```

### 3. Teil 2 ausführen

```bash
./install_part2.sh
```

---

## Wichtige Hinweise

### Für kleine GPUs (16GB VRAM):
- ✅ **Empfohlen**: Qwen/Qwen3-4B-Instruct-2507 (Option 1)
- ❌ **Nicht empfohlen**: Qwen3-30B (Option 2) - zu groß!

### Credentials:
- Werden automatisch generiert und in `~/kaepsele_credentials.txt` gespeichert
- Werden während der Installation auf dem Bildschirm angezeigt
- **Unbedingt notieren** für die spätere OpenWebUI-Konfiguration!

### Installation dauert:
- Teil 1: ~10-15 Minuten (+ Neustart)
- Teil 2: ~20-30 Minuten (abhängig von Download-Geschwindigkeit)

### Troubleshooting:
- Logs prüfen: `docker logs -f <container-name>`
- GPU-Status: `nvidia-smi`
- Container-Status: `docker ps`

Viel Erfolg mit der Installation! 🚀
