# Einrichtung eines GPU-Servers zur Bereitstellung eines On-Premise-Sprachmodells mittels OpenWebUI

## Über dieses Projekt

Dies ist ein **Tandemprojekt** im Rahmen des Digital Fellowship-Programms, gefördert durch:

<div align="right">
  <img src="https://github.com/ProfEngel/OpenTuneWeaver/blob/main/assets/mwk_logo_w2.png" alt="Ministry of Science, Research and Arts Logo" height="60">
  <img src="https://github.com/ProfEngel/OpenTuneWeaver/blob/main/assets/stifterverband_logo.jpg" alt="Stifterverband Logo" height="60">
</div>

**Projektleitung:** Prof. Dr. Mathias Engel & Tobias Leiblein  
**Institution:** Hochschule für Wirtschaft und Umwelt Nürtingen-Geislingen

Dieses Projekt ist Teil des [Fellowship-Programms 2024](https://www.stifterverband.org/bwdigifellows/2024_engel_leiblein) und wird gefördert vom **Ministerium für Wissenschaft, Forschung und Kunst Baden-Württemberg (MWK)** sowie dem **Stifterverband Deutschland**.

---

## ⚠️ WICHTIGER SICHERHEITSHINWEIS

**Diese Anleitung enthält Platzhalter für sensible Daten!**

Alle API-Schlüssel, Tokens und Passwörter in dieser Anleitung sind **BEISPIELE** und müssen durch eigene, sichere Werte ersetzt werden:

- Suchen Sie nach: `ERSETZEN-MIT-` in allen Code-Blöcken
- Generieren Sie sichere Tokens mit: `openssl rand -hex 32`
- Verwenden Sie einen Passwort-Manager für die Verwaltung
- **NIEMALS** Beispiel-Credentials in Produktion verwenden!
- Dokumentieren Sie Ihre Credentials sicher und getrennt vom System

---

## 0. Firewallrichtlinien und Port-Konfiguration

### Port-Übersicht

Die folgenden Ports müssen je nach Nutzungsszenario konfiguriert werden:

| Port | Dienst | Zweck | Firewall öffnen? |
|------|--------|-------|------------------|
| **80** | OpenWebUI | ChatUI - Hauptbenutzeroberfläche | ✅ Extern (wenn Remote-Zugriff gewünscht) |
| **11434** | Ollama | Embedding-Modelle & LLM-Bereitstellung | ❌ Nur lokal (127.0.0.1) |
| **8000** | vLLM/Llama.cpp | Primäres Produktiv-Sprachmodell | ❌ Nur lokal (via OpenWebUI) |
| **8001+** | vLLM/Llama.cpp | Weitere Sprachmodelle | ❌ Nur lokal |
| **4000** | SearXNG | Metasuchmaschine | ⚠️ Optional extern |
| **3000** | Perplexica | Frontend | ⚠️ Optional extern |
| **3001** | Perplexica Backend | Backend-Service | ❌ Nur lokal |
| **7870** | StableDiffusion Forge | Bilderstellung | ⚠️ Optional extern |
| **9099** | Pipeline-Docker | OpenWebUI Pipelines | ❌ Nur lokal |

**Wichtige Hinweise:**
- **Lokale Nutzung**: Wenn alle Services nur auf demselben Server genutzt werden, müssen KEINE Ports in der Firewall geöffnet werden
- **Remote-Zugriff**: Nur Port 80 (oder 443 für HTTPS) für OpenWebUI öffnen - alle anderen Services werden über OpenWebUI proxied
- **Sicherheit**: Niemals die Backend-Ports (11434, 8000, 3001, 9099) extern freigeben!

### Firewall-Konfiguration (nur bei Remote-Zugriff)

```bash
# Nur wenn externer Zugriff gewünscht ist:
sudo ufw allow 80/tcp    # OpenWebUI
# Optional für direkte Service-Nutzung (nicht empfohlen):
# sudo ufw allow 4000/tcp  # SearXNG
# sudo ufw allow 3000/tcp  # Perplexica
# sudo ufw allow 7870/tcp  # StableDiffusion
```

## 1. Installation relevanter OS-Updates und Tools

### Aktualisierung des Systems
```bash
sudo apt update && sudo apt upgrade -y
```
Stellt sicher, dass das Betriebssystem auf dem neuesten Stand ist.

### Installation von grundlegenden Tools
```bash
sudo apt install -y build-essential wget curl git htop net-tools
```
Diese Tools sind notwendig für Softwareentwicklung, Downloads und Systemüberwachung.

## 2. Einrichtung von Miniconda

### Miniconda-Installationsskript herunterladen
```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
```

### Installationsskript headless ausführen
```bash
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3
```
- `-b`: Aktiviert den Batch-Modus (kein Eingreifen erforderlich)
- `-p $HOME/miniconda3`: Gibt den Installationspfad an

### Miniconda initialisieren
```bash
~/miniconda3/bin/conda init
```

### Shell neu starten
```bash
exec bash
```

### Installation testen
```bash
conda --version
```

### Optional: Automatische Aktualisierung
```bash
conda update -n base -c defaults conda -y
```

## 3. Einrichtung der NVIDIA GPU

### Überprüfen der GPU
```bash
lspci | grep -i nvidia
```

### Installation des NVIDIA-Treibers
```bash
# Verfügbare Treiber anzeigen
ubuntu-drivers devices

# Empfohlenen Treiber installieren (oder spezifische Version)
sudo apt install -y nvidia-driver-550
# Alternative: automatische Installation des empfohlenen Treibers
# sudo ubuntu-drivers autoinstall

sudo reboot
```

### GPU-Status überprüfen
```bash
nvidia-smi
```

## 4. Installation des CUDA-Toolkits

### Für Ubuntu 22.04
```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-6
```

### Für Ubuntu 24.04
```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-6
```

### Umgebungsvariablen setzen
```bash
echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

### Test der Installation
```bash
nvcc --version
```

## 5. Docker-Installation

### Installation von Docker
```bash
# Docker GPG-Schlüssel hinzufügen
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Repository hinzufügen
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker installieren
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker-Service aktivieren
sudo systemctl start docker
sudo systemctl enable docker

# Benutzer zur Docker-Gruppe hinzufügen (optional)
sudo usermod -aG docker $USER
# Hinweis: Nach diesem Befehl neu einloggen oder "newgrp docker" ausführen
```

### Installation des NVIDIA Container Toolkits
```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Installation von Docker Compose (falls nicht bereits installiert)
```bash
# Prüfen ob Docker Compose bereits installiert ist
docker compose version

# Falls nicht installiert, manuell installieren:
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Installation testen
```bash
# Docker testen
docker run hello-world

# Docker mit GPU testen
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
```

## 6. Installation von OpenWebUI

### OpenWebUI mit Codeinterpreter und Ollama
```bash
docker run -d \
  -p 80:8080 \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -v open-webui:/app/backend/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --add-host=host.docker.internal:host-gateway \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

**Hinweise:**
- Port 80 wird nur auf 8080 intern gemappt
- `host.docker.internal` ermöglicht Zugriff auf Host-Services
- Docker-Socket-Zugriff für Code-Interpreter

### Code-Interpreter mit Jupyter-Container einrichten

#### 1. Jupyter-Container erstellen und bereitstellen
```bash
docker run -d \
  -p 8888:8888 \
  --name jupyter-interpreter \
  --restart always \
  jupyter/datascience-notebook \
  start.sh jupyter notebook \
  --NotebookApp.token='ERSETZEN-MIT-SICHEREM-TOKEN' \
  --NotebookApp.password='' \
  --NotebookApp.allow_origin='*' \
  --NotebookApp.disable_check_xsrf=True
```

⚠️ **SICHERHEITSHINWEIS:** 
- Ersetzen Sie `ERSETZEN-MIT-SICHEREM-TOKEN` durch einen sicheren, zufälligen Token!
- Beispiel für sicheren Token: `$(openssl rand -hex 32)` generiert einen 64-stelligen Hex-String
- NIEMALS den Beispiel-Token in Produktion verwenden!

#### 2. Bibliotheken installieren

Erstellen Sie eine `requirements.txt` mit folgendem Inhalt:

```txt
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
```

Installation im Container:
```bash
docker exec jupyter-interpreter pip install -r requirements.txt
```

#### 3. In OpenWebUI konfigurieren

1. Navigieren Sie zu: **Admin > Einstellungen > Code Execution**
2. Konfigurieren Sie:
   - **Execution Backend**: Jupyter
   - **Jupyter Base URL**: `http://host.docker.internal:8888`
   - **Jupyter Token**: Der oben gesetzte Token

### Bereitstellen von OpenWebUI Pipelines

```bash
docker run -d \
  -p 9099:9099 \
  --add-host=host.docker.internal:host-gateway \
  -v pipelines:/app/pipelines \
  --name pipelines \
  --restart always \
  ghcr.io/open-webui/pipelines:main
```

**Verbindung zu OpenWebUI herstellen:**
1. Navigieren Sie zu: **Admin > Einstellungen > Verbindungen**
2. Neue Verbindung hinzufügen (+)
3. Konfigurieren:
   - **API-URL**: `http://host.docker.internal:9099`
   - **API-Schlüssel**: `ERSETZEN-MIT-EIGENEM-API-KEY`

⚠️ **SICHERHEITSHINWEIS:** Der Schlüssel `0p3n-w3bu!` ist nur ein Beispiel! Verwenden Sie einen eigenen, sicheren API-Schlüssel.

## 7. Bereitstellung der Sprachmodelle

## 7.1 Option A: Llama.cpp (Ressourcenschonend)

### Vorbereitung
```bash
# Modellordner erstellen
mkdir -p /root/modelle/GGUF/phi4

# Modell herunterladen (Beispiel: Phi-4 14B)
wget https://huggingface.co/unsloth/phi-4-GGUF/resolve/main/phi-4-Q4_K_M.gguf \
  -O /root/modelle/GGUF/phi4/phi-4-Q4_K_M.gguf
```

### Docker-Container starten
```bash
docker run -d \
  --gpus all \
  --name phi4-llama \
  --restart always \
  -v /root/modelle/GGUF/phi4:/models \
  -p 8000:8000 \
  ghcr.io/ggerganov/llama.cpp:server-cuda \
  -m /models/phi-4-Q4_K_M.gguf \
  --host 0.0.0.0 \
  --port 8000 \
  --n-gpu-layers -1 \
  --api-key sk-ERSETZEN-MIT-SICHEREM-API-KEY \
  --parallel 4 \
  --ctx-size 4096 \
  --flash-attn
```

⚠️ **SICHERHEITSHINWEIS:** 
- Ersetzen Sie `sk-ERSETZEN-MIT-SICHEREM-API-KEY` durch einen eigenen, sicheren API-Schlüssel!
- Beispiel für sicheren Schlüssel generieren: `echo "sk-$(openssl rand -hex 32)"`
- Dieser Schlüssel wird für die Authentifizierung bei API-Anfragen benötigt

**Parameter-Erklärung:**
- `--n-gpu-layers -1`: Alle Layer auf GPU (maximale Performance)
- `--parallel 4`: Anzahl gleichzeitiger Anfragen (an Hardware anpassen)
- `--ctx-size 4096`: Kontextgröße (an Modell und VRAM anpassen)
- `--flash-attn`: Flash Attention für bessere Performance

## 7.2 Option B: vLLM (Höhere Performance)

### Docker-Image ziehen
```bash
docker pull vllm/vllm-openai:latest
mkdir -p /root/.cache/huggingface
```

### vLLM mit quantisiertem Modell starten
```bash
docker run -d \
  --gpus all \
  --shm-size 16g \
  --restart unless-stopped \
  -p 8000:8000 \
  -v /root/.cache/huggingface:/root/.cache/huggingface \
  -e HF_HUB_ENABLE_HF_TRANSFER=1 \
  --name vllm-server \
  vllm/vllm-openai:latest \
  --model hugging-quants/Meta-Llama-3.1-8B-Instruct-AWQ-INT4 \
  --max-model-len 4096 \
  --port 8000 \
  --api-key sk-ERSETZEN-MIT-SICHEREM-API-KEY \
  --max-num-seqs 8 \
  --gpu-memory-utilization 0.95
```

⚠️ **SICHERHEITSHINWEIS:** 
- Ersetzen Sie `sk-ERSETZEN-MIT-SICHEREM-API-KEY` durch einen eigenen API-Schlüssel!
- Verwenden Sie denselben Schlüssel wie bei Llama.cpp, wenn beide nicht gleichzeitig laufen

## 7.3 Option C: SG-Lang (Alternative)

```bash
docker run -d \
  --gpus all \
  --shm-size 32g \
  -p 8000:8000 \
  -v /root/sglang/cache:/root/.cache/huggingface \
  --env "HF_TOKEN=hf_ERSETZEN-MIT-HUGGINGFACE-TOKEN" \
  --name sglang-server \
  --restart always \
  lmsysorg/sglang:latest \
  python3 -m sglang.launch_server \
  --model-path hugging-quants/Meta-Llama-3.1-8B-Instruct-AWQ-INT4 \
  --api-key sk-ERSETZEN-MIT-SICHEREM-API-KEY \
  --host 0.0.0.0 \
  --port 8000
```

⚠️ **SICHERHEITSHINWEIS:** 
- `HF_TOKEN`: Ersetzen Sie mit Ihrem HuggingFace-Token von https://huggingface.co/settings/tokens
- `api-key`: Ersetzen Sie mit einem eigenen sicheren API-Schlüssel für die Zugriffskontrolle

## 8. Einrichtung von SearXNG (Metasuchmaschine)

### Konfigurationsdatei erstellen
```bash
mkdir -p /root/docker/searxng
nano /root/docker/searxng/settings.yml
```

### Konfiguration (settings.yml)
```yaml
use_default_settings: true

server:
  secret_key: "ERSETZEN-MIT-ZUFAELLIGEM-SECRET-KEY"
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
```

⚠️ **SICHERHEITSHINWEIS:** 
- Ersetzen Sie `ERSETZEN-MIT-ZUFAELLIGEM-SECRET-KEY` durch einen zufälligen Schlüssel!
- Generieren mit: `openssl rand -hex 32`
- Dieser Schlüssel wird für die interne Verschlüsselung verwendet

### SearXNG Container starten
```bash
docker run -d \
  --name searxng \
  -e BASE_URL=http://localhost:4000 \
  -e SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml \
  -v /root/docker/searxng/settings.yml:/etc/searxng/settings.yml \
  -p 4000:8080 \
  --restart always \
  searxng/searxng
```

## 9. Installation von Perplexica (KI-gestützte Suche)

### 1. Repository klonen
```bash
cd /root/docker
git clone https://github.com/ItzCrazyKns/Perplexica.git
cd Perplexica
```

### 2. Konfigurationsdateien anpassen

#### config.toml
```bash
nano config.toml
```

```toml
[API_KEYS]
OPENAI = ""
GROQ = ""
ANTHROPIC = ""
GEMINI = ""

[API_ENDPOINTS]
OLLAMA = "http://host.docker.internal:11434"
SEARXNG = "http://searxng:8080"

[GENERAL]
PORT = 3001
SIMILARITY_MEASURE = "cosine"
KEEP_ALIVE = "5m"
```

#### docker-compose.yaml
```bash
nano docker-compose.yaml
```

```yaml
services:
  searxng:
    image: docker.io/searxng/searxng:latest
    volumes:
      - ./searxng:/etc/searxng:rw
    ports:
      - 4000:8080
    networks:
      - perplexica-network
    restart: unless-stopped

  perplexica-backend:
    build:
      context: .
      dockerfile: backend.dockerfile
    image: itzcrazykns1337/perplexica-backend:main
    environment:
      - SEARXNG_API_URL=http://searxng:8080
    depends_on:
      - searxng
    ports:
      - 3001:3001
    volumes:
      - backend-dbstore:/home/perplexica/data
      - uploads:/home/perplexica/uploads
      - ./config.toml:/home/perplexica/config.toml
    extra_hosts:
      - 'host.docker.internal:host-gateway'
    networks:
      - perplexica-network
    restart: unless-stopped

  perplexica-frontend:
    build:
      context: .
      dockerfile: app.dockerfile
      args:
        - NEXT_PUBLIC_API_URL=http://localhost:3001/api
        - NEXT_PUBLIC_WS_URL=ws://localhost:3001
    image: itzcrazykns1337/perplexica-frontend:main
    depends_on:
      - perplexica-backend
    ports:
      - 3000:3000
    networks:
      - perplexica-network
    restart: unless-stopped

networks:
  perplexica-network:

volumes:
  backend-dbstore:
  uploads:
```

### 3. Docker-Container starten
```bash
docker compose up -d
```

### 4. Zugriff auf Perplexica
- **Lokal**: `http://localhost:3000`
- **Remote**: `http://<SERVER-IP>:3000`

## 10. Installation von Stable Diffusion Forge

### Repository klonen und Umgebung einrichten
```bash
cd /root/docker
git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git
cd stable-diffusion-webui-forge

# Conda-Umgebung erstellen
conda create --name sd-forge python=3.10 -y
conda activate sd-forge

# Abhängigkeiten installieren
pip install -r requirements.txt
```

### webui.sh anpassen (Root-Check deaktivieren)
```bash
nano webui.sh
```

Kommentieren Sie die Root-Überprüfung aus:
```bash
# if [ "$EUID" -eq 0 ]; then
#   echo "This script must not be launched as root, aborting..."
#   exit 1
# fi
```

### Modelle herunterladen
```bash
# FLUX-Modell
cd models/Stable-diffusion
wget -O flux1-dev-bnb-nf4.safetensors \
  "https://huggingface.co/lllyasviel/flux1-dev-bnb-nf4/resolve/main/flux1-dev-bnb-nf4.safetensors"

# SDXL-Modell
wget -O juggernautXL_v8Rundiffusion.safetensors \
  "https://huggingface.co/RunDiffusion/Juggernaut-XL-v8/resolve/main/juggernautXL_v8Rundiffusion.safetensors"
```

### Systemd-Service für automatischen Start

```bash
sudo nano /etc/systemd/system/sd-forge.service
```

```ini
[Unit]
Description=Stable Diffusion Forge Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/docker/stable-diffusion-webui-forge
ExecStart=/bin/bash -c "source /root/miniconda3/etc/profile.d/conda.sh && conda activate sd-forge && ./webui.sh --listen --port 7870 --api --api-auth BENUTZERNAME:PASSWORT"
Restart=always
Environment="PATH=/root/miniconda3/envs/sd-forge/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
```

⚠️ **SICHERHEITSHINWEIS:** 
- Ersetzen Sie `BENUTZERNAME:PASSWORT` durch eigene, sichere Anmeldedaten!
- Beispiel: `admin:$(openssl rand -base64 16)`
- Diese Credentials werden für den WebUI-Zugriff benötigt - notieren Sie sie!

### Service aktivieren
```bash
sudo systemctl daemon-reload
sudo systemctl enable sd-forge.service
sudo systemctl start sd-forge.service

# Status prüfen
sudo systemctl status sd-forge.service
```

## 11. Installation und Nutzung von Ollama

### Installation
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Empfohlene Modelle installieren
```bash
# Multimodales Vision-Modell
ollama pull llama3.2-vision

# SOTA Embedding-Modell
ollama pull granite-embedding:278m

# Vision-Modell (Alternative)
ollama pull minicpm-v

# Generatives KI-Modell
ollama pull phi4
```

### Ollama-Service konfigurieren
```bash
sudo nano /etc/systemd/system/ollama.service
```

```ini
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
Environment="OLLAMA_NUM_PARALLEL=4"
Environment="OLLAMA_KEEP_ALIVE=5m"
Environment="OLLAMA_MAX_QUEUE=256"

[Install]
WantedBy=default.target
```

### Service neu starten
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
sudo systemctl enable ollama
```

### Nützliche Ollama-Befehle
```bash
# Verfügbare Modelle anzeigen
ollama list

# Laufende Modelle anzeigen
ollama ps

# Modell testen
ollama run phi4 --verbose

# Modell entfernen
ollama rm modelname
```

## 12. OpenWebUI Konfiguration

### Modellverbindungen einrichten

1. **Admin > Einstellungen > Verbindungen**

2. **OpenAI API** (für vLLM/Llama.cpp):
   - **URL**: `http://host.docker.internal:8000/v1`
   - **API-Schlüssel**: Der oben bei vLLM/Llama.cpp gesetzte Schlüssel

3. **Ollama-Verbindung**:
   - **URL**: `http://host.docker.internal:11434`

⚠️ **HINWEIS:** Verwenden Sie hier den API-Schlüssel, den Sie bei der Einrichtung von vLLM oder Llama.cpp festgelegt haben.

### Embedding-Modell konfigurieren

**Admin > Einstellungen > Dokumente**:
- **Embedding-Modell-Engine**: Ollama
- **URL**: `http://host.docker.internal:11434`
- **Stapelgröße**: 16
- **Embedding-Modell**: `granite-embedding:278m`
- **Top K**: 5
- **Blockgröße**: 800
- **Blocküberlappung**: 100

### Websuche aktivieren

**Admin > Einstellungen > Web Search**:
- **Websuche aktivieren**: Ja
- **Suchmaschine**: SearxNG
- **Query URL**: `http://host.docker.internal:4000/search?q=<query>`
- **Ergebnisse**: 5
- **Gleichzeitige Anfragen**: 10

### Bildgenerierung einrichten

**Admin > Einstellungen > Images**:
- **Engine**: Automatic1111
- **Base URL**: `http://host.docker.internal:7870/`
- **API Auth**: Die bei Stable Diffusion gesetzten Credentials

⚠️ **HINWEIS:** Verwenden Sie die Anmeldedaten, die Sie im Stable Diffusion Systemd-Service festgelegt haben.

## 13. Wartung und Troubleshooting

### Docker-Container verwalten
```bash
# Alle Container anzeigen
docker ps -a

# Container-Logs anzeigen
docker logs <container-name>

# Container neustarten
docker restart <container-name>

# Container stoppen/starten
docker stop <container-name>
docker start <container-name>
```

### OpenWebUI aktualisieren
```bash
# Mit Watchtower
docker run --rm \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --run-once open-webui

# Manuell
docker pull ghcr.io/open-webui/open-webui:main
docker stop open-webui
docker rm open-webui
# Dann Container neu erstellen mit obigem Befehl
```

### Dateien finden
```bash
# OpenWebUI Daten-Speicherort
docker volume inspect open-webui

# Uploads befinden sich in:
/var/lib/docker/volumes/open-webui/_data/uploads
```

### System-Monitoring
```bash
# GPU-Auslastung
nvidia-smi -l 1

# Docker-Ressourcennutzung
docker stats

# System-Ressourcen
htop

# Netzwerk-Verbindungen prüfen
netstat -tulpn | grep LISTEN
```

## 14. Sicherheitsempfehlungen

1. **Firewall konfigurieren**: Nur notwendige Ports öffnen
2. **Sichere API-Schlüssel**: Lange, zufällige Schlüssel verwenden
3. **Regelmäßige Updates**: System und Container aktuell halten
4. **Backup**: Regelmäßige Sicherungen der Docker-Volumes
5. **HTTPS einrichten**: Für Produktivumgebungen Reverse-Proxy mit SSL/TLS
6. **Monitoring**: Log-Überwachung und Anomalie-Erkennung

## 15. Performance-Optimierung

### GPU-Memory Management
```bash
# In vLLM/Llama.cpp Konfiguration anpassen:
--gpu-memory-utilization 0.95  # Maximale GPU-Nutzung
--max-model-len 4096           # An verfügbaren VRAM anpassen
```

### Docker Resource Limits
```bash
# Bei Container-Erstellung hinzufügen:
--memory="32g"                 # RAM-Limit
--cpus="8.0"                  # CPU-Limit
--gpus '"device=0"'           # Spezifische GPU zuweisen
```

### Netzwerk-Optimierung
```bash
# Docker-Netzwerk für interne Kommunikation
docker network create ai-network

# Container mit Netzwerk starten
docker run --network ai-network ...
```

---

**Hinweis:** Diese Anleitung ist für Ubuntu 22.04/24.04 LTS optimiert. Bei anderen Distributionen können Anpassungen notwendig sein.

## 📋 Checkliste: Zu ersetzende Sicherheits-Credentials

Vor dem produktiven Einsatz müssen Sie folgende Platzhalter durch eigene, sichere Werte ersetzen:

| Service | Platzhalter | Verwendung | Generierung |
|---------|------------|------------|-------------|
| **Jupyter** | `ERSETZEN-MIT-SICHEREM-TOKEN` | Notebook-Zugriff | `openssl rand -hex 32` |
| **Pipelines** | `ERSETZEN-MIT-EIGENEM-API-KEY` | API-Authentifizierung | `openssl rand -hex 24` |
| **Llama.cpp** | `sk-ERSETZEN-MIT-SICHEREM-API-KEY` | Model-API-Zugriff | `echo "sk-$(openssl rand -hex 32)"` |
| **vLLM** | `sk-ERSETZEN-MIT-SICHEREM-API-KEY` | Model-API-Zugriff | Gleicher wie Llama.cpp |
| **SG-Lang** | `hf_ERSETZEN-MIT-HUGGINGFACE-TOKEN` | HuggingFace-Zugriff | Von huggingface.co/settings/tokens |
| **SG-Lang** | `sk-ERSETZEN-MIT-SICHEREM-API-KEY` | API-Authentifizierung | `echo "sk-$(openssl rand -hex 32)"` |
| **SearXNG** | `ERSETZEN-MIT-ZUFAELLIGEM-SECRET-KEY` | Interne Verschlüsselung | `openssl rand -hex 32` |
| **SD-Forge** | `BENUTZERNAME:PASSWORT` | WebUI-Zugriff | Eigene Wahl + `openssl rand -base64 16` |

**Support:** Bei Fragen wenden Sie sich an das Projektteam der HfWU Nürtingen-Geislingen.
