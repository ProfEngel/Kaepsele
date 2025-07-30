# AI-Tutor für die Hochschullehre - GPU-Server Setup für On-Premise Sprachmodelle

## 📚 Über das Projekt

Dieses Setup ist Teil des **Tandemforschungsprojekts** von **Tobias Leiblein** und **Prof. Dr. Mathias Engel** (Hochschule für Wirtschaft und Umwelt Nürtingen-Geislingen), gefördert durch das **Fellowship für Lehrinnovationen und Unterstützungsangebote in der digitalen Hochschullehre Baden-Württemberg**.

### Projektzielsetzung

Das Forschungsprojekt entwickelt und erprobt einen **KI-Tutor für die Hochschullehre**, der mithilfe von **OpenTuneWeaver** - einer eigens entwickelten Trainingspipeline - optimierte und für die Lehre angepasste Sprachmodelle bereitstellt. 

**Kernziele:**
- **Qualitative Bewertung:** Analyse des Lernoutputs und der Akzeptanz durch Lehrende
- **Didaktische Integration:** Entwicklung hochschuldidaktischer Angebote zur Technologie-Integration
- **Skalierbarkeit:** Erhebung von Ressourcennutzungsdaten als Grundlage für eine landesweite Bereitstellung
- **Prä-Post-Kompetenzmatrix:** Bestimmung der optimalen Lehrziele und Anwendungsszenarien

### OpenTuneWeaver - Die Trainingspipeline

[**OpenTuneWeaver**](https://github.com/ProfEngel/OpenTuneWeaver) ist ein Framework zur:
- **Datensatzkonvertierung** von PDFs zu strukturierten Q&A-Formaten
- **Finetuning von Open-Source-LLMs** für spezifische Lehrdomänen
- **Automatisierter Modellgenerierung** mit anwenderfreundlicher UI
- **GGUF-Export** für direkte lokale Nutzung in OpenWebUI

**Technische Features:**
- Integration von QLORA und LORA Fine-tuning
- Realtime-Metriken und Loss-Kurven-Monitoring
- Automatischer Hugging Face Model-Upload
- Support für verschiedene Trainingsdatenformate (Q&A, Chat, Function Calling)

---

**Gefördert von:**

<div style="display: flex; align-items: center; gap: 30px; margin: 20px 0;">
  <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Stifterverband_f%C3%BCr_die_Deutsche_Wissenschaft_Logo_02.2022.svg/300px-Stifterverband_f%C3%BCr_die_Deutsche_Wissenschaft_Logo_02.2022.svg.png" alt="Stifterverband für die Deutsche Wissenschaft" style="height: 60px;">
  <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Greater_coat_of_arms_of_Baden-W%C3%BCrttemberg.svg/80px-Greater_coat_of_arms_of_Baden-W%C3%BCrttemberg.svg.png" alt="Ministerium für Wissenschaft, Forschung und Kunst Baden-Württemberg" style="height: 60px;">
</div>

**Stifterverband für die Deutsche Wissenschaft** und **Ministerium für Wissenschaft, Forschung und Kunst Baden-Württemberg**

---

# Einrichtung eines GPU-Servers zur Bereitstellung eines On-Premise-Sprachmodells mittels OpenWebUI

## ⚠️ Sicherheitshinweise

**KRITISCH: Diese Anleitung wurde für Produktionsumgebungen überarbeitet**

- **Niemals** Credentials, API-Keys oder Passwörter in Klartext verwenden
- Alle Platzhalter `YOUR_*` und `<REPLACE_*>` durch echte Werte ersetzen
- Sichere Passwörter und API-Keys generieren
- Firewall-Regeln restriktiv konfigurieren
- Services nicht als root laufen lassen (wo möglich)
- Regelmäßige Updates und Sicherheitspatches einspielen

## 0. Firewall-Konfiguration

### Benötigte Ports

| Port | Service | Extern zugänglich | Beschreibung |
|------|---------|------------------|--------------|
| 80 | OpenWebUI | ✅ | Web-Interface für Chat |
| 8000-8010 | vLLM/Models | ⚠️ | API-Endpunkte (nur bei Bedarf) |
| 11434 | Ollama | ⚠️ | Embedding-/Vision-Modelle |
| 3000 | Perplexica Frontend | ✅ | Alternative Search UI |
| 3001 | Perplexica Backend | ❌ | Interne API |
| 4000 | SearXNG | ⚠️ | Metasuchmaschine |
| 7870 | Stable Diffusion | ⚠️ | Bildgenerierung |
| 8888 | Jupyter | ❌ | Code-Interpreter |
| 9099 | OpenWebUI Pipelines | ❌ | Interne Pipelines |

### Firewall einrichten

```bash
# UFW (Uncomplicated Firewall) zurücksetzen - entfernt alle vorherigen Regeln
sudo ufw --force reset

# Standardregeln: Eingehende Verbindungen blockieren, ausgehende erlauben
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH-Zugang sicherstellen (anpassen an Ihren SSH-Port)
# WICHTIG: Ohne diese Regel verlieren Sie SSH-Zugang!
sudo ufw allow 22/tcp

# Nur notwendige Ports für den AI-Stack öffnen
sudo ufw allow 80/tcp    # OpenWebUI - für Web-Interface des Chatbots
# sudo ufw allow 3000/tcp  # Perplexica (nur bei Bedarf) - für erweiterte Suchfunktionen

# UFW aktivieren - ab jetzt sind die Regeln aktiv
sudo ufw --force enable

# Status anzeigen - zeigt alle aktiven Firewall-Regeln
sudo ufw status verbose
```
*Diese Konfiguration wird **zu Beginn einmalig** ausgeführt und sichert den Server ab.*

## 1. Grundlegende Systemkonfiguration

### System-Updates und Tools

```bash
# System aktualisieren - holt neueste Sicherheitsupdates und Paketinformationen
sudo apt update && sudo apt upgrade -y

# Grundlegende Entwicklungstools installieren
sudo apt install -y \
    build-essential \    # Compiler und Build-Tools für Software-Kompilierung
    wget \              # Download-Tool für Dateien aus dem Internet
    curl \              # Vielseitiges Tool für HTTP-Requests und Downloads
    git \               # Versionskontrolle für Code-Repositories
    htop \              # Erweiterte Systemüberwachung (besseres top)
    ufw \               # Firewall-Management
    fail2ban \          # Schutz vor Brute-Force-Angriffen
    unattended-upgrades # Automatische Sicherheitsupdates

# Automatische Sicherheitsupdates aktivieren - System hält sich selbst aktuell
sudo dpkg-reconfigure -plow unattended-upgrades
```
*Diese Befehle werden **einmalig** nach der Server-Installation ausgeführt.*

## 2. Miniconda-Installation

```bash
# Miniconda-Installer herunterladen (neueste Version für Linux x86_64)
# Miniconda = minimale Python-Distribution mit Paketmanager conda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

# Installation im Batch-Modus (keine Benutzerinteraktion erforderlich)
# -b = Batch-Modus, -p = Installationspfad festlegen
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3

# Conda für aktuelle Shell-Sitzung initialisieren
# Fügt conda-Befehle zur PATH-Variable hinzu
~/miniconda3/bin/conda init

# Shell neu starten um conda-Konfiguration zu laden
exec bash

# Conda-Version prüfen - verifiziert erfolgreiche Installation
conda --version

# Conda selbst aktualisieren auf neueste Version
conda update -n base -c defaults conda -y
```
*Diese Schritte werden **einmalig** ausgeführt und richten die Python-Umgebung ein.*

## 3. NVIDIA GPU-Setup

### GPU-Treiber installieren (Aktuell: 570.x/575.x)

```bash
# GPU-Hardware-Erkennung - zeigt alle NVIDIA-Karten im System
lspci | grep -i nvidia

# Option 1: Stabile Production Branch installieren (empfohlen für Server)
# 570er Serie = langzeitunterstützt, getestet, stabil
sudo apt install -y nvidia-driver-570

# System neustarten - Treiber wird erst nach Reboot aktiv
sudo reboot

# Option 2: New Feature Branch (für neueste Features, nur wenn nötig)
# 575er Serie = neueste Features, aber weniger getestet
# sudo apt install -y nvidia-driver-575
# sudo reboot

# Nach Neustart: GPU-Status und Treiberinfo anzeigen
nvidia-smi  # Zeigt GPU-Auslastung, Temperatur, Speicher

# Genaue Treiber-Version anzeigen
nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits
```
*Wird **einmalig** nach der Basis-Installation ausgeführt. **Neustart erforderlich!***

### CUDA-Toolkit installieren (Aktuell: 12.9)

#### Für Ubuntu 22.04:
```bash
# NVIDIA CUDA Repository-Schlüssel herunterladen und installieren
# Ermöglicht sicheren Download von CUDA-Paketen
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb

# Paketlisten aktualisieren - lädt CUDA-Repository-Informationen
sudo apt-get update

# CUDA Toolkit 12.9 installieren - vollständige Entwicklungsumgebung
# Benötigt ~6GB Speicherplatz
sudo apt-get -y install cuda-toolkit-12-9
```

#### Für Ubuntu 24.04:
```bash
# Gleicher Prozess für Ubuntu 24.04 (neuere Repository-URL)
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-9
```

### CUDA-Umgebung konfigurieren

```bash
# CUDA-Binaries zur PATH-Variable hinzufügen
# Ermöglicht Verwendung von nvcc (CUDA-Compiler) und anderen Tools
cat >> ~/.bashrc << 'EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
EOF

# Umgebungsvariablen sofort laden (ohne Shell-Neustart)
source ~/.bashrc

# CUDA-Compiler-Version prüfen - verifiziert erfolgreiche Installation
nvcc --version
```
*Diese Konfiguration ist **einmalig** nach CUDA-Installation erforderlich.*

## 4. Docker und Container-Runtime

### Docker installieren

```bash
# Docker Engine und Docker Compose aus Ubuntu-Repository installieren
# Einfacher als Docker's eigenes Repository, ausreichend für unsere Zwecke
sudo apt install -y docker.io docker-compose

# Docker-Service starten und für Autostart konfigurieren
sudo systemctl start docker    # Startet Docker sofort
sudo systemctl enable docker   # Startet Docker automatisch beim Bootvorgang

# NVIDIA Container Toolkit installieren - ermöglicht GPU-Zugriff in Containern
# GPG-Schlüssel für sicheren Download hinzufügen
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# Repository zur Paketliste hinzufügen
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Paketlisten aktualisieren und NVIDIA Container Toolkit installieren
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Docker für GPU-Nutzung konfigurieren
sudo nvidia-ctk runtime configure --runtime=docker

# Docker-Services neustarten um Konfiguration zu aktivieren
sudo systemctl restart docker

# Docker Compose von GitHub herunterladen (neueste Version)
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Docker Compose ausführbar machen
sudo chmod +x /usr/local/bin/docker-compose

# Installation verifizieren
docker --version        # Zeigt Docker-Version
docker-compose --version  # Zeigt Docker Compose-Version
```
*Diese Installation erfolgt **einmalig** und ist Grundlage für alle Container-Services.*

### Benutzer für Services erstellen

```bash
# WICHTIG: Erst NACH Docker-Installation ausführen!
# Dedizierten Benutzer für AI-Services erstellen (Security Best Practice)
# -r = System-User (keine Login-Shell), -s = Shell festlegen, -m = Home-Verzeichnis erstellen
sudo useradd -r -s /bin/false -m aiservices

# Benutzer zur Docker-Gruppe hinzufügen - erlaubt Docker-Container-Verwaltung
# Die docker-Gruppe existiert erst nach Docker-Installation!
sudo usermod -aG docker aiservices

# Überprüfen ob User korrekt zur Gruppe hinzugefügt wurde
groups aiservices  # Sollte "aiservices : aiservices docker" anzeigen
```
*Wird **einmalig nach Docker-Installation** ausgeführt. Services laufen nicht als root = sicherer.*

## 5. Credential-Management

### Sichere API-Keys generieren

```bash
# Sicheres Verzeichnis für alle Credentials erstellen
mkdir -p ~/.ai-credentials
chmod 700 ~/.ai-credentials  # Nur Owner kann lesen/schreiben/ausführen

echo "Generiere sichere API-Keys..."

# Haupt-API-Key für vLLM/Modelle generieren (64 Zeichen Hex)
# Wird für Authentifizierung bei Sprachmodell-APIs verwendet
MAIN_API_KEY="sk-$(openssl rand -hex 32)"
echo "$MAIN_API_KEY" > ~/.ai-credentials/main_api_key

# Jupyter-Token für Code-Interpreter generieren
# Sichert Zugang zum Jupyter-Notebook-Server
JUPYTER_TOKEN=$(openssl rand -hex 32)
echo "$JUPYTER_TOKEN" > ~/.ai-credentials/jupyter_token

# StableDiffusion-Credentials für Bildgenerierung
SD_USERNAME="admin"
SD_PASSWORD=$(openssl rand -base64 24)  # Base64 für komplexere Zeichen
echo "$SD_USERNAME:$SD_PASSWORD" > ~/.ai-credentials/sd_auth

# Perplexica-Secret für Suchfunktionen
PERPLEXICA_SECRET=$(openssl rand -hex 32)
echo "$PERPLEXICA_SECRET" > ~/.ai-credentials/perplexica_secret

# Alle Credential-Dateien vor unbefugtem Zugriff schützen
chmod 600 ~/.ai-credentials/*

echo "API-Keys generiert und gespeichert in ~/.ai-credentials/"
echo "WICHTIG: Diese Keys sicher aufbewahren und niemals in Code/Logs committen!"
```
*Wird **einmalig** ausgeführt. Diese Keys werden von allen Services verwendet.*

### Umgebungsvariablen-Datei erstellen

```bash
# Docker-Umgebungsdatei mit Pfaden zu Secret-Dateien erstellen
# Verwendet Docker Secrets statt Klartext-Variablen
cat > ~/.ai-credentials/docker.env << EOF
# Generiert am: $(date)
MAIN_API_KEY_FILE=/run/secrets/main_api_key
JUPYTER_TOKEN_FILE=/run/secrets/jupyter_token
SD_AUTH_FILE=/run/secrets/sd_auth
PERPLEXICA_SECRET_FILE=/run/secrets/perplexica_secret

# Netzwerk-Konfiguration - ANPASSEN an Ihre Server-IP!
HOST_IP=YOUR_SERVER_IP  # ÄNDERN: z.B. 192.168.1.100
INTERNAL_HOST=host.docker.internal

# Service-Port-Konfiguration
OLLAMA_HOST=0.0.0.0:11434
VLLM_HOST=0.0.0.0:8000
WEBUI_PORT=80
EOF

chmod 600 ~/.ai-credentials/docker.env
```

**Server-IP herausfinden:**
```bash
# Interne IP-Adresse des Servers anzeigen
ip addr show | grep -E "inet.*eth0|inet.*wlan0" | awk '{print $2}' | cut -d/ -f1

# Oder spezifischer für Ethernet-Verbindung:
hostname -I | awk '{print $1}'

# Beispiel-Ausgabe: 192.168.1.100
# Diese IP dann in docker.env eintragen:
# HOST_IP=192.168.1.100

# Externe IP für Internet-Zugriff (falls benötigt):
curl -s ifconfig.me  # Zeigt öffentliche IP
```
*Diese IP-Adresse wird in **allen Container-Konfigurationen** verwendet für Netzwerk-Verbindungen.*

## 6. OpenWebUI mit sicherem Setup

### OpenWebUI mit normalem Docker starten

```bash
# OpenWebUI als einzelner Docker-Container starten (einfacher für Updates)
# Alle erforderlichen Features in einem Befehl
docker run -d \
  --name open-webui \
  --restart unless-stopped \
  -p 80:8080 \
  -v open-webui:/app/backend/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  -e WEBUI_NAME="AI-Tutor für die Hochschullehre" \
  -e ENABLE_COMMUNITY_SHARING=false \
  -e ENABLE_SIGNUP=false \
  --add-host=host.docker.internal:host-gateway \
  ghcr.io/open-webui/open-webui:main

# Container-Status überprüfen
docker ps | grep open-webui

# Logs anzeigen um sicherzustellen dass alles funktioniert
docker logs open-webui -f
```
*Startet OpenWebUI als **einzelnen Container** - einfacher zu verwalten und zu aktualisieren.*

### Code-Interpreter mit Jupyter (Endlosschleifen-geschützt)

```bash
# Jupyter-Container für Code-Ausführung starten
# Verwendet sicheres Token aus unseren Credentials
JUPYTER_TOKEN=$(cat ~/.ai-credentials/jupyter_token)

# Container mit Timeout-Schutz und Resource-Limits starten
docker run -d \
  --name jupyter-interpreter \
  --restart unless-stopped \
  -p 127.0.0.1:8888:8888 \
  -v jupyter-data:/home/jovyan/work \
  -e JUPYTER_ENABLE_LAB=yes \
  -e JUPYTER_TOKEN="$JUPYTER_TOKEN" \
  --cpus="2.0" \
  --memory="4g" \
  --ulimit nofile=1024:1024 \
  jupyter/base-notebook:latest \
  bash -c "
    pip install pandas numpy scipy matplotlib seaborn scikit-learn requests beautifulsoup4 && 
    start-notebook.sh 
    --NotebookApp.ip=0.0.0.0 
    --NotebookApp.port=8888 
    --NotebookApp.token=$JUPYTER_TOKEN
    --NotebookApp.disable_check_xsrf=True
    --NotebookApp.allow_root=True
    --NotebookApp.shutdown_no_activity_timeout=1800
  "

# Container-Status prüfen
docker ps | grep jupyter

# Jupyter-Zugang im Browser: http://YOUR_SERVER_IP:8888
# Token eingeben: [Inhalt aus ~/.ai-credentials/jupyter_token]
```
*Jupyter läuft **nur auf localhost** mit **Resource-Limits** gegen Endlosschleifen.*

### Bibliotheken im Jupyter-Notebook installieren

**Nach dem ersten Jupyter-Start im Browser:**

1. **Neues Notebook erstellen** (Python 3)
2. **Erste Zelle:** Bibliotheken installieren
```python
# Kern-Bibliotheken für Datenanalyse und Wissenschaft
!pip install --upgrade pip

# Datenverarbeitung und -analyse
!pip install pandas          # Datenmanipulation und -analyse
!pip install numpy           # Numerische Berechnungen und Arrays
!pip install scipy          # Wissenschaftliche Berechnungen

# Visualisierung und Plotting
!pip install matplotlib     # Basis-Plotting-Bibliothek
!pip install seaborn        # Statistische Datenvisualisierung
!pip install plotly         # Interaktive Graphiken

# Machine Learning und AI
!pip install scikit-learn   # Machine Learning Algorithmen
!pip install torch          # PyTorch für Deep Learning
!pip install transformers   # Hugging Face Transformers

# Dokumentenverarbeitung
!pip install pypdf          # PDF-Dateien lesen und verarbeiten
!pip install python-docx    # Word-Dokumente verarbeiten
!pip install openpyxl       # Excel-Dateien lesen/schreiben
!pip install xlsxwriter     # Excel-Dateien erstellen

# Web und APIs
!pip install requests       # HTTP-Requests und API-Aufrufe
!pip install beautifulsoup4 # HTML/XML-Parsing und Web-Scraping
!pip install httpx          # Moderner HTTP-Client

# Utilities und Tools
!pip install qrcode         # QR-Code-Generierung
!pip install pillow         # Bildverarbeitung
!pip install python-pptx    # PowerPoint-Präsentationen
!pip install reportlab      # PDF-Generierung

print("✅ Alle Bibliotheken erfolgreich installiert!")
```

3. **Zweite Zelle:** Installation testen
```python
# Test der wichtigsten Bibliotheken
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import requests

print("🎉 Jupyter-Umgebung ist bereit für AI-Tutor-Entwicklung!")

# Beispiel-Plot erstellen
data = np.random.randn(100)
plt.figure(figsize=(8, 4))
plt.hist(data, bins=20, alpha=0.7)
plt.title("Test-Visualisierung")
plt.show()
```

**Endlosschleifen-Schutz aktivieren:**
```python
# In jeder Code-Zelle diese Timeout-Funktion verwenden:
import signal
import time

def timeout_handler(signum, frame):
    raise TimeoutError("Code-Ausführung nach 30 Sekunden abgebrochen!")

# Timeout für Endlosschleifen-Schutz setzen
signal.signal(signal.SIGALRM, timeout_handler)
signal.alarm(30)  # 30 Sekunden Timeout

# Hier Ihren Code einfügen...
# for i in range(1000000):  # Beispiel-Code
#     time.sleep(0.001)

signal.alarm(0)  # Timeout zurücksetzen
print("Code erfolgreich ausgeführt!")
```
*Diese Konfiguration **schützt vor Endlosschleifen** und bietet alle nötigen Bibliotheken.*

### Automatische Updates mit Watchtower

```bash
# Manuelles Update von OpenWebUI testen
# Watchtower prüft auf neue Images und aktualisiert automatisch
docker run --rm \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --run-once open-webui

# Automatische wöchentliche Updates einrichten (Freitag 16:00 Uhr)
# Crontab-Eintrag erstellen für regelmäßige Updates
(crontab -l 2>/dev/null; echo "0 16 * * 5 docker run --rm --volume /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once open-webui") | crontab -

# Crontab-Eintrag verifizieren
crontab -l | grep watchtower

# Optional: Update-Log erstellen für Nachverfolgung
(crontab -l 2>/dev/null | grep -v watchtower; echo "0 16 * * 5 docker run --rm --volume /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once open-webui >> /var/log/openwebui-updates.log 2>&1") | crontab -

# Log-Datei erstellen
sudo touch /var/log/openwebui-updates.log
sudo chmod 644 /var/log/openwebui-updates.log
```
*Updates laufen **automatisch jeden Freitag um 16:00** - ideal für Wochenend-Wartung.*

### Update-Status überwachen

```bash
# Aktuellen OpenWebUI-Container und Image-Version anzeigen
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep open-webui

# Update-History in Logs prüfen
tail -f /var/log/openwebui-updates.log

# Manuelles Update für sofortige Aktualisierung
docker run --rm \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --run-once open-webui \
  --cleanup  # Entfernt alte Images nach Update
```
*Ermöglicht **einfache Überwachung** des Update-Prozesses und manueller Updates bei Bedarf.*

## 7. Modell-Deployment: vLLM vs Ollama

### 🚀 vLLM - Hochperformante Produktionsumgebung

**vLLM ist optimiert für:**
- **Maximale Durchsatzrate** und niedrige Latenz in Produktionsumgebungen
- **Batch Processing** mit optimaler GPU-Auslastung
- **Advanced Features** wie speculative decoding, kontinuierliches batching
- **Enterprise-Grade APIs** mit OpenAI-Kompatibilität
- **Quantisierte Modelle** (INT8, FP8) für bessere Effizienz

### 🔧 Ollama - Entwicklungsfreundliche Umgebung

**Ollama ist ideal für:**
- **Einfache Installation** und schnelles Prototyping
- **Multi-Modell-Management** (Text, Vision, Embedding)
- **Development Workflows** mit einfacher API
- **Resource Management** mit automatischem Model Loading/Unloading
- **Community-Fokus** mit vielen verfügbaren Modellen

---

## 7.1 vLLM-Deployment (Produktionsumgebung)

## 7.1 vLLM-Deployment (Produktionsumgebung)

### Schritt 1: Conda-Umgebung vorbereiten

```bash
# Dedizierte Conda-Umgebung für vLLM erstellen
# Isoliert vLLM-Dependencies von anderen Python-Paketen
conda create -n vllm-gemma python=3.10 -y

# Umgebung aktivieren
conda activate vllm-gemma

# Bestätigung der aktiven Umgebung
conda info --envs | grep "*"
```
*Erstellt **isolierte Python-Umgebung** für saubere vLLM-Installation.*

### Schritt 2: vLLM und Dependencies installieren

```bash
# vLLM mit Flash Attention installieren (für bessere Performance)
pip install vllm

# Flash Attention für Ampere/Ada GPUs (RTX 30/40-Serie)
pip install flash-attn

# Installation verifizieren
python -c "import vllm; print('✅ vLLM erfolgreich installiert')"
```
*Installiert **hochperformante Inference-Engine** mit GPU-Optimierungen.*

### Schritt 3: Systemd-Service erstellen

```bash
# Service-Datei für automatischen Start erstellen
sudo nano /etc/systemd/system/vllm-gemma.service
```

**Service-Konfiguration einfügen:**
```ini
[Unit]
Description=vLLM Gemma 3 12B INT8 Production Server
Documentation=https://docs.vllm.ai/
After=network.target nvidia-persistenced.service  # Wartet auf Netzwerk und GPU-Treiber
Wants=network.target

[Service]
Type=exec
User=aiservices  # Läuft nicht als root = sicherer
Group=aiservices
WorkingDirectory=/home/aiservices

# Umgebungsvariablen für vLLM
Environment="PATH=/root/miniconda3/envs/vllm-gemma/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="CUDA_VISIBLE_DEVICES=0"  # Verwendet erste GPU
Environment="VLLM_WORKER_MULTIPROC_METHOD=spawn"  # Für Stabilität
Environment="VLLM_LOGGING_LEVEL=INFO"  # Detaillierte Logs

# vLLM-Server starten mit Gemma 3 12B INT8-Modell
ExecStart=/root/miniconda3/envs/vllm-gemma/bin/vllm serve \
  RedHatAI/gemma-3-12b-it-quantized.w8a8 \
  --host 127.0.0.1 \
  --port 8000 \
  --api-key-file /home/aiservices/.ai-credentials/main_api_key \
  --served-model-name gemma-3-12b \
  --max-model-len 4096 \
  --max-num-seqs 16 \
  --tensor-parallel-size 1 \
  --gpu-memory-utilization 0.9 \
  --enable-chunked-prefill \
  --max-num-batched-tokens 8192

# Automatischer Neustart bei Fehlern
Restart=always
RestartSec=10
StartLimitInterval=300
StartLimitBurst=5

# Sicherheitseinstellungen
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/home/aiservices/.cache
PrivateTmp=true

# Resource-Limits (Gemma 3 12B benötigt ~16GB GPU VRAM + ~32GB RAM)
MemoryMax=32G
CPUQuota=400%

[Install]
WantedBy=multi-user.target
```

### Schritt 4: Berechtigungen konfigurieren

```bash
# API-Key für aiservices-User kopieren (Service läuft als dieser User)
sudo mkdir -p /home/aiservices/.ai-credentials
sudo cp ~/.ai-credentials/main_api_key /home/aiservices/.ai-credentials/

# Dateiberechtigungen setzen
sudo chown -R aiservices:aiservices /home/aiservices/.ai-credentials
sudo chmod 700 /home/aiservices/.ai-credentials
sudo chmod 600 /home/aiservices/.ai-credentials/main_api_key

# Berechtigungen verifizieren
sudo ls -la /home/aiservices/.ai-credentials/
```
*Konfiguriert **sichere Dateiberechtigungen** für Service-Account.*

### Schritt 5: Service aktivieren und starten

```bash
# Systemd-Konfiguration neu laden
sudo systemctl daemon-reload

# Service für automatischen Start aktivieren
sudo systemctl enable vllm-gemma

# Service sofort starten
sudo systemctl start vllm-gemma

# Service-Status prüfen
sudo systemctl status vllm-gemma
```

### Schritt 6: Installation verifizieren

```bash
# Live-Logs anzeigen - zeigt Startvorgang und eventuelle Fehler
sudo journalctl -u vllm-gemma -f

# API-Funktionalität testen
curl -X POST "http://127.0.0.1:8000/v1/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(cat ~/.ai-credentials/main_api_key)" \
  -d '{
    "model": "gemma-3-12b",
    "prompt": "Erkläre mir maschinelles Lernen in einfachen Worten:",
    "max_tokens": 200,
    "temperature": 0.7
  }'

# Erfolgreiche Antwort sollte JSON mit "choices" enthalten
```
*Dieser Service läuft **permanent** und startet automatisch nach Server-Neustart.*

### Alternative: vLLM mit Docker (Secure)

```bash
# Docker-basierte vLLM-Konfiguration
cat > ~/docker/vllm-gemma-compose.yml << 'EOF'
version: '3.8'

services:
  vllm-gemma:
    image: vllm/vllm-openai:latest
    container_name: vllm-gemma-prod
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"  # Nur localhost
    volumes:
      - ~/.cache/huggingface:/root/.cache/huggingface
    environment:
      - HF_HUB_ENABLE_HF_TRANSFER=1
      - CUDA_VISIBLE_DEVICES=0
      - VLLM_LOGGING_LEVEL=INFO
    runtime: nvidia
    command: >
      --model RedHatAI/gemma-3-12b-it-quantized.w8a8
      --host 0.0.0.0
      --port 8000
      --api-key-file /run/secrets/main_api_key
      --served-model-name gemma-3-12b
      --max-model-len 4096
      --max-num-seqs 16
      --gpu-memory-utilization 0.9
      --enable-chunked-prefill
      --max-num-batched-tokens 8192
    secrets:
      - main_api_key
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

secrets:
  main_api_key:
    file: ~/.ai-credentials/main_api_key
EOF

# vLLM starten
docker-compose -f ~/docker/vllm-gemma-compose.yml up -d

# Performance-Test
curl -X POST "http://127.0.0.1:8000/v1/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(cat ~/.ai-credentials/main_api_key)" \
  -d '{
    "model": "gemma-3-12b",
    "prompt": "Erkläre mir maschinelles Lernen in einfachen Worten:",
    "max_tokens": 200,
    "temperature": 0.7
  }'
```

## 7.2 Ollama für Embedding- und Vision-Modelle (Entwicklungsumgebung)

## 7.2 Ollama für Embedding- und Vision-Modelle (Entwicklungsumgebung)

### Schritt 1: Ollama installieren

```bash
# Ollama mit dem offiziellen Installationsskript installieren
# Ollama = benutzerfreundliche Plattform für lokale LLM-Ausführung
curl -fsSL https://ollama.com/install.sh | sh

# Installation verifizieren
ollama --version
```
*Installiert **Ollama-Server** für einfache Modell-Verwaltung.*

### Schritt 2: Systemd-Service konfigurieren

```bash
# Sichere Systemd-Konfiguration erstellen
sudo nano /etc/systemd/system/ollama.service
```

**Service-Konfiguration einfügen:**
```ini
[Unit]
Description=Ollama Service
Documentation=https://github.com/ollama/ollama
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve  # Startet Ollama-Server
User=ollama    # Eigener System-User für Sicherheit
Group=ollama
Restart=always  # Automatischer Neustart bei Absturz
RestartSec=3

# Umgebungsvariablen für Ollama-Konfiguration
Environment="PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="OLLAMA_HOST=127.0.0.1:11434"      # Nur localhost = sicherer
Environment="OLLAMA_MAX_LOADED_MODELS=2"       # Max 2 Modelle gleichzeitig im RAM
Environment="OLLAMA_NUM_PARALLEL=8"            # 8 parallele Anfragen pro Modell
Environment="OLLAMA_KEEP_ALIVE=5m"             # Modell 5 Min im RAM behalten
Environment="OLLAMA_MAX_QUEUE=128"             # Warteschlangengröße
Environment="OLLAMA_CONTEXT_LENGTH=4096"       # Kontext-Länge für Gespräche

[Install]
WantedBy=multi-user.target
```

### Schritt 3: Service starten

```bash
# Systemd-Konfiguration neu laden und Service starten
sudo systemctl daemon-reload
sudo systemctl enable ollama    # Automatischer Start beim Boot
sudo systemctl start ollama     # Sofort starten

# Service-Status prüfen
sudo systemctl status ollama
```
*Startet **Ollama-Server** im Hintergrund für Modell-Management.*

### Schritt 4: Embedding-Modell installieren

```bash
# Bestes multilinguales Embedding-Modell für deutsche/englische RAG-Systeme
# Quantisiert für effizienten Speicherverbrauch
ollama pull jeffh/intfloat-multilingual-e5-large:q8_0

# Modell-Download verifizieren
ollama list | grep multilingual
```
*Installiert **spezialisiertes RAG-Embedding-Modell** für Dokumentensuche.*

### Schritt 5: Hauptsprachmodell installieren (optional)

```bash
# Option 1: Gemma 3 12B (für Server mit 16GB+ VRAM)
ollama pull gemma3:12b-it-qat

# Option 2: Kleinere Alternative für weniger VRAM (< 12GB)
# Siehe https://ollama.com/search für aktuelle Modelle
# ollama pull gemma3:8b-it-qat    # Für 8GB VRAM
# ollama pull llama3.2:3b-it      # Für 4GB VRAM

# Verfügbare Modelle anzeigen
ollama list
```
*Installiert **Entwicklungs-Sprachmodell** für Tests (parallel zu vLLM-Produktion).*

### Schritt 6: Installation verifizieren

```bash
# Alle installierten Modelle anzeigen
ollama list

# Embedding-Modell testen
echo "Hallo Welt" | ollama embeddings jeffh/intfloat-multilingual-e5-large:q8_0

# Service-Status final prüfen
sudo systemctl status ollama

# Speicherverbrauch überwachen
docker stats 2>/dev/null || echo "Ollama läuft nativ (nicht in Docker)"
```
*Ollama läuft **permanent** für Embedding/Vision-Aufgaben während der Entwicklung.*

**Modell-Übersicht:**
- **jeffh/intfloat-multilingual-e5-large:q8_0:** RAG-Embeddings (deutsch/englisch)
- **gemma3:12b-it-qat:** Entwicklungs-Sprachmodell (parallel zu vLLM)
- **Weitere Modelle:** https://ollama.com/search nach Bedarf

## 8. Suchfunktionen (Optional)

### Was ist Perplexica?

**Perplexica** ist eine **KI-gestützte Suchmaschine**, die:
- Internetsuchen mit **AI-Antworten** kombiniert
- **Quellen automatisch zusammenfasst** und bewertet
- **Multimodale Suche** (Text, Bilder, Videos) ermöglicht
- **Lokale LLMs** für Datenschutz verwendet

**Anwendung im AI-Tutor:** Studenten können komplexe Fragen stellen und erhalten strukturierte, quellenbasierte Antworten statt einzelner Suchergebnisse.

### Option A: Perplexica (Vollständige KI-Suchmaschine)

#### Schritt 1: Repository klonen

```bash
# Perplexica-Repository herunterladen
cd ~/docker
git clone https://github.com/ItzCrazyKns/Perplexica.git
cd Perplexica
```

#### Schritt 2: Konfiguration anpassen

```bash
# Konfigurationsdatei für lokale Modelle erstellen
cat > config.toml << 'EOF'
[API_KEYS]
OPENAI = ""
GROQ = ""
ANTHROPIC = ""
GEMINI = ""

[API_ENDPOINTS]
OLLAMA = "http://host.docker.internal:11434"   # Verbindung zu unserem Ollama
SEARXNG = "http://searxng:8080"               # Interne Suchmaschine

[GENERAL]
PORT = 3001
SIMILARITY_MEASURE = "cosine"
KEEP_ALIVE = "5m"
EOF
```

#### Schritt 3: Docker-Container starten

```bash
# Perplexica mit integrierter SearXNG starten
# SERVER_IP durch Ihre echte IP ersetzen!
SERVER_IP=$(hostname -I | awk '{print $1}')  # Dieser Befehl findet Ihre IP

cat > docker-compose.yml << EOF
version: '3.8'

services:
  searxng:
    image: docker.io/searxng/searxng:latest
    container_name: perplexica-searxng
    volumes:
      - ./searxng:/etc/searxng:rw
    ports:
      - "127.0.0.1:4000:8080"  # Nur localhost
    networks:
      - perplexica-network
    restart: unless-stopped

  perplexica-backend:
    build:
      context: .
      dockerfile: backend.dockerfile
    container_name: perplexica-backend
    environment:
      - SEARXNG_API_URL=http://searxng:8080
    depends_on:
      - searxng
    ports:
      - "127.0.0.1:3001:3001"  # Nur localhost
    volumes:
      - backend-dbstore:/home/perplexica/data
      - uploads:/home/perplexica/uploads
      - ./config.toml:/home/perplexica/config.toml:ro
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
        - NEXT_PUBLIC_API_URL=http://$SERVER_IP:3001/api
        - NEXT_PUBLIC_WS_URL=ws://$SERVER_IP:3001
    container_name: perplexica-frontend
    depends_on:
      - perplexica-backend
    ports:
      - "3000:3000"
    networks:
      - perplexica-network
    restart: unless-stopped

networks:
  perplexica-network:
    driver: bridge

volumes:
  backend-dbstore:
  uploads:
EOF

# Container starten
docker-compose up -d

# Status prüfen
docker-compose ps
```
*Perplexica ist unter **http://YOUR_SERVER_IP:3000** erreichbar.*

### Option B: Nur SearXNG (Einfache Metasuchmaschine)

**Für einfachere Setups ohne KI-Suchfunktionen:**

```bash
# Minimale SearXNG-Installation
mkdir -p ~/docker/searxng
cd ~/docker/searxng

# SearXNG-Konfiguration
cat > settings.yml << 'EOF'
use_default_settings: true

server:
  secret_key: "$(openssl rand -hex 32)"
  limiter: false
  image_proxy: true
  port: 8080
  bind_address: "0.0.0.0"

ui:
  static_use_hash: true

search:
  safe_search: 0
  autocomplete: ""
  default_lang: "de"
  formats:
    - html
    - json
EOF

# SearXNG-Container starten
docker run -d \
  --name searxng \
  --restart unless-stopped \
  -p 127.0.0.1:4000:8080 \
  -v $(pwd)/settings.yml:/etc/searxng/settings.yml:ro \
  searxng/searxng

# Status prüfen
docker ps | grep searxng
```
*SearXNG ist unter **http://127.0.0.1:4000** erreichbar.*

### OpenWebUI-Integration

**Beide Optionen in OpenWebUI unter Websuche konfigurieren:**

```
# Für Perplexica:
Suchmaschine: SearXNG
SearxNG-URL: http://host.docker.internal:4000/search?q=<query>

# Für nur SearXNG:  
Suchmaschine: SearXNG
SearxNG-URL: http://host.docker.internal:4000/search?q=<query>

Suchergebnisse: 5
Gleichzeitige Anfragen: 8
```
*Aktiviert **Echtzeit-Internetsuche** für aktuelle Informationen.*

## 9. ComfyUI für Bildgenerierung (Optional)

### Was ist ComfyUI?

**ComfyUI** ist eine **node-basierte UI für Stable Diffusion**, die:
- **Workflow-basierte Bildgenerierung** ermöglicht
- **FLUX-Modelle** optimal unterstützt (inkl. FLUX.1-Kontext)
- **Modulare Pipelines** für komplexe Generierungen bietet
- **Bessere Performance** als WebUI Forge hat

### Installation (Manual Install)

```bash
# Python-Umgebung für ComfyUI erstellen
conda create --name comfyui python=3.10 -y
conda activate comfyui

# ComfyUI Repository klonen
cd ~/docker
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# Dependencies installieren
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install -r requirements.txt

# Installation testen
python main.py --help
```

### FLUX.1-Kontext Setup

**Für optimale FLUX-Performance folgen Sie der detaillierten Anleitung:**

🔗 **ComfyUI FLUX Tutorial:** https://comfyui-wiki.com/en/tutorial/advanced/image/flux/flux-1-kontext

**Wichtige FLUX-Modelle herunterladen:**
```bash
# Modell-Verzeichnis erstellen
mkdir -p models/checkpoints
mkdir -p models/vae
mkdir -p models/clip

# FLUX.1-dev Modell (falls verfügbar und lizenziert)
# Hinweis: FLUX-Modelle haben spezielle Lizenzanforderungen
# wget -O models/checkpoints/flux1-dev.safetensors "FLUX_MODEL_URL"
```

### Systemd-Service für ComfyUI

```bash
# Service-Datei erstellen
SD_AUTH=$(cat ~/.ai-credentials/sd_auth)

sudo tee /etc/systemd/system/comfyui.service > /dev/null << EOF
[Unit]
Description=ComfyUI Service for AI Image Generation
After=network.target nvidia-persistenced.service

[Service]
Type=simple
User=aiservices
Group=aiservices
WorkingDirectory=/home/aiservices/ComfyUI
ExecStart=/bin/bash -c "source /root/miniconda3/etc/profile.d/conda.sh && conda activate comfyui && python main.py --listen --port 7870 --disable-auto-launch"
Restart=always
Environment="PATH=/root/miniconda3/envs/comfyui/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Sicherheitseinstellungen
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/home/aiservices/ComfyUI

[Install]
WantedBy=multi-user.target
EOF

# ComfyUI-Installation zu aiservices-User kopieren
sudo cp -r ~/docker/ComfyUI /home/aiservices/
sudo chown -R aiservices:aiservices /home/aiservices/ComfyUI

# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable comfyui
sudo systemctl start comfyui

# Status prüfen
sudo systemctl status comfyui
```

### ComfyUI-Zugriff

```bash
# ComfyUI-Interface aufrufen:
# http://YOUR_SERVER_IP:7870

# Logs überwachen
sudo journalctl -u comfyui -f

# Service-Status prüfen
sudo systemctl status comfyui
```

### OpenWebUI-Integration

**ComfyUI als Bildgenerierungs-Backend konfigurieren:**

**Einstellungen > Bildgenerierung in OpenWebUI:**
```
Engine: ComfyUI
Basis-URL: http://host.docker.internal:7870/
API-Endpunkt: /api/prompt
```

### Erweiterte Konfiguration

**Für FLUX.1-Kontext und andere erweiterte Features:**

📖 **Vollständige Dokumentation:**
- **ComfyUI Manual Install:** https://github.com/comfyanonymous/ComfyUI#manual-install-windows-linux
- **FLUX.1-Kontext Tutorial:** https://comfyui-wiki.com/en/tutorial/advanced/image/flux/flux-1-kontext

**Hinweise:**
- ComfyUI benötigt **mindestens 12GB VRAM** für FLUX-Modelle
- **Workflow-Dateien** können in der Community geteilt werden
- **Custom Nodes** erweitern die Funktionalität erheblich

*ComfyUI läuft **permanent** und bietet **professionelle Bildgenerierung** für Lehrmaterialien.*

## 11. Langfuse für AI-Telemetrie (Optional)

### Was ist Langfuse?

**Langfuse** ist eine **Open-Source-Plattform** für:
- **LLM-Observability:** Überwachung von AI-Modell-Performance
- **Kosten-Tracking:** API-Aufrufe und Ressourcenverbrauch
- **Quality-Monitoring:** Antwortqualität und Benutzer-Feedback  
- **Analytics:** Nutzungsstatistiken für Forschungszwecke

**Nutzen für den AI-Tutor:** Analysieren Sie, wie Studierende den Chatbot nutzen, welche Fragen gestellt werden und wie gut die Antworten sind.

### Langfuse mit OpenWebUI integrieren

#### Schritt 1: Langfuse-Container starten

```bash
# Langfuse mit PostgreSQL-Datenbank starten
docker run -d \
  --name langfuse \
  --restart unless-stopped \
  -p 127.0.0.1:3030:3000 \
  -e DATABASE_HOST=langfuse-db \
  -e DATABASE_USERNAME=langfuse \
  -e DATABASE_PASSWORD=$(openssl rand -base64 32) \
  -e DATABASE_NAME=langfuse \
  -e NEXTAUTH_SECRET=$(openssl rand -base64 32) \
  -e SALT=$(openssl rand -base64 32) \
  --network langfuse-net \
  langfuse/langfuse:latest

# PostgreSQL-Datenbank für Langfuse
docker run -d \
  --name langfuse-db \
  --restart unless-stopped \
  -e POSTGRES_DB=langfuse \
  -e POSTGRES_USER=langfuse \
  -e POSTGRES_PASSWORD=$(cat ~/.ai-credentials/main_api_key | head -c 32) \
  -v langfuse-db:/var/lib/postgresql/data \
  --network langfuse-net \
  postgres:15

# Docker-Netzwerk erstellen
docker network create langfuse-net 2>/dev/null || true

# Services starten
docker start langfuse-db langfuse

# Status prüfen
docker ps | grep langfuse
```

#### Schritt 2: Langfuse konfigurieren

```bash
# Langfuse-Webinterface aufrufen: http://127.0.0.1:3030
# Ersten Admin-Account erstellen

# API-Keys für OpenWebUI-Integration generieren
echo "1. Gehen Sie zu http://127.0.0.1:3030"
echo "2. Erstellen Sie einen Account"
echo "3. Navigieren Sie zu Settings > API Keys"
echo "4. Erstellen Sie neue API-Keys für OpenWebUI"
echo "5. Notieren Sie: Public Key und Secret Key"
```

#### Schritt 3: OpenWebUI mit Langfuse verbinden

**Folgen Sie der offiziellen Anleitung:** https://langfuse.com/integrations/no-code/openwebui

**In OpenWebUI konfigurieren:**

1. **Admin-Panel > Einstellungen > Externe Verbindungen**
2. **Langfuse-Integration aktivieren:**
```
Langfuse Host: http://127.0.0.1:3030
Public Key: [Aus Langfuse kopieren]
Secret Key: [Aus Langfuse kopieren]
```

3. **Telemetrie-Einstellungen:**
```
☑ Conversation Tracking
☑ Model Performance Monitoring  
☑ User Feedback Collection
☑ Cost Tracking (falls API-basiert)
```

#### Schritt 4: Monitoring-Dashboard einrichten

```bash
# Langfuse-Analytics aufrufen
echo "Analytics verfügbar unter: http://127.0.0.1:3030/analytics"

# Beispiel-Metriken die erfasst werden:
echo "📊 Verfügbare Metriken:"
echo "- Anzahl Gespräche pro Tag/Woche"
echo "- Durchschnittliche Antwortzeit"
echo "- Häufigste Fragen/Themen"
echo "- Benutzer-Feedback-Scores"
echo "- Modell-Performance-Vergleiche"
echo "- Ressourcenverbrauch (GPU/RAM)"
```

### Datenschutz-Konfiguration

```bash
# Datenschutz-konforme Einstellungen
cat > ~/langfuse-privacy.conf << 'EOF'
# Langfuse Datenschutz-Konfiguration für Hochschule

# Anonymisierung aktivieren
LANGFUSE_ENABLE_EXPERIMENTAL_FEATURES=true
LANGFUSE_ANONYMIZE_USER_DATA=true

# Datenaufbewahrung (DSGVO-konform)
LANGFUSE_DATA_RETENTION_DAYS=365  # 1 Jahr für Forschungszwecke

# IP-Adressen nicht loggen
LANGFUSE_LOG_IP_ADDRESSES=false

# Sensible Daten filtern
LANGFUSE_FILTER_PERSONAL_DATA=true
EOF

echo "⚠️ WICHTIG: Datenschutz-Richtlinien der Hochschule beachten!"
echo "📋 DSGVO-Compliance sicherstellen vor Produktiveinsatz!"
```

### Analytics für Forschung

**Mögliche Forschungsfragen mit Langfuse-Daten:**
- Welche Fachbereiche nutzen den AI-Tutor am meisten?
- Zu welchen Uhrzeiten ist die Nutzung am höchsten?
- Welche Fragetypen führen zu den besten Bewertungen?
- Wie entwickelt sich die Antwortqualität über Zeit?

```bash
# Export für Forschungsanalyse
echo "Daten-Export für Forschung:"
echo "1. Langfuse > Analytics > Export"
echo "2. CSV/JSON-Format für statistische Analyse"
echo "3. Anonymisierte Daten für Publikationen"
```

*Langfuse ermöglicht **wissenschaftlich fundierte Evaluierung** des AI-Tutors für das Forschungsprojekt.*

### Modellverbindungen einrichten

**Nach dem ersten Start von OpenWebUI im Browser (http://YOUR_SERVER_IP):**

1. **Admin-Account erstellen** beim ersten Besuch der Website
2. **SIGNUP deaktivieren** unter Admin-Einstellungen (verhindert weitere Registrierungen)
3. **Administrationsbereich > Einstellungen > Verbindungen** aufrufen

#### vLLM-Verbindung (Gemma 3):
```
URL: http://host.docker.internal:8000/v1
API-Key: [Inhalt aus ~/.ai-credentials/main_api_key kopieren]
Modell: gemma-3-12b
```
*Diese Verbindung ermöglicht Zugriff auf das **Produktions-Sprachmodell** für Lehrzwecke.*

#### Ollama-Verbindung:
```
URL: http://host.docker.internal:11434
```
*Aktiviert **Vision-Modelle** und **Embedding-Funktionen** für RAG-Systeme.*

### Embedding-Modell konfigurieren

**Dokumente > Einstellungen:** *(Ermöglicht Upload und Durchsuchung von PDF-Dokumenten)*
```
Embedding-Engine: Ollama                    # Verwendet Ollama für Texteinbettungen
URL: http://host.docker.internal:11434      # Interne Container-Verbindung
Embedding-Modell: granite-embedding:278m    # IBM's spezialisiertes Modell
Stapelgröße: 16                             # Verarbeitet 16 Textblöcke gleichzeitig
Top K: 5                                    # Zeigt 5 relevanteste Suchergebnisse
Blockgröße: 800                             # 800 Zeichen pro Textblock
Blocküberlappung: 100                       # 100 Zeichen Überlappung zwischen Blöcken
```
*Konfiguration für **RAG-Funktionalität** - ermöglicht Wissensabfrage aus eigenen Dokumenten.*

### Websuche aktivieren

**Einstellungen > Websuche:** *(Erweitert Chatbot um aktuelle Internetinformationen)*
```
Suchmaschine: SearXNG                                              # Privacy-fokussierte Metasuchmaschine
SearxNG-URL: http://host.docker.internal:4000/search?q=<query>     # Interne Suchservice-Verbindung
Suchergebnisse: 5                                                  # Anzahl der Suchergebnisse pro Anfrage
Gleichzeitige Anfragen: 8                                          # Parallel-Suchen für bessere Performance
```
*Aktiviert **Echtzeit-Internetsuche** für aktuelle Informationen und Faktencheck.*

### Bildgenerierung konfigurieren

**Einstellungen > Bildgenerierung:** *(Fügt AI-Bildgenerierung zum Chatbot hinzu)*
```
Engine: Automatic1111                                    # Kompatibel mit Stable Diffusion Forge
Basis-URL: http://host.docker.internal:7870/            # Interne Verbindung zu SD Forge
API-Auth: [Inhalt aus ~/.ai-credentials/sd_auth]        # Benutzername:Passwort für Authentifizierung
```
*Ermöglicht **Bildgenerierung** direkt im Chat für visuelle Lehrmaterialien.*

### Code-Interpreter aktivieren

**Einstellungen > Code Execution:** *(Aktiviert Programmcode-Ausführung im Chat)*
```
Engine: Jupyter                                         # Jupyter Notebook als Code-Umgebung
URL: http://host.docker.internal:8888                   # Jupyter-Server-Verbindung
Token: [Inhalt aus ~/.ai-credentials/jupyter_token]     # Sicherheits-Token für Jupyter-Zugriff
```
*Erlaubt **Code-Ausführung** für Datenanalyse, Berechnungen und Programmierung im Chat.*

## 12. Wartung und Monitoring

### Systemüberwachung

```bash
# System-Monitoring-Script erstellen für regelmäßige Überwachung
cat > ~/monitor-ai-stack.sh << 'EOF'
#!/bin/bash
echo "=== AI Stack Status Check ==="
echo "Date: $(date)"
echo

# Zeigt verfügbaren RAM und Swap-Speicher
echo "=== System Resources ==="
free -h
echo

# Zeigt verfügbaren Festplattenspeicher (Root-Partition)
df -h /
echo

# GPU-Status: Auslastung und Speicherverbrauch
echo "=== GPU Status ==="
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
echo

# Status aller AI-Services prüfen
echo "=== Service Status ==="
echo "vLLM Gemma: $(sudo systemctl is-active vllm-gemma)"
echo "Ollama: $(sudo systemctl is-active ollama)"
echo "Stable Diffusion: $(sudo systemctl is-active sd-forge 2>/dev/null || echo 'not-installed')"

echo
# Übersicht aller laufenden Docker-Container mit Image-Versionen
echo "=== Docker Containers ==="
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo
# Zeigt welche Services auf welchen Ports lauschen
echo "=== Port Status ==="
sudo netstat -tlnp | grep -E ':(80|8000|11434|3000|7870|8888) '

echo
# OpenWebUI Update-History anzeigen (letzte 5 Einträge)
echo "=== Recent OpenWebUI Updates ==="
if [ -f /var/log/openwebui-updates.log ]; then
    tail -5 /var/log/openwebui-updates.log
else
    echo "No update log found yet (updates run Fridays at 16:00)"
fi
EOF

# Script ausführbar machen
chmod +x ~/monitor-ai-stack.sh

# Script ausführen um aktuellen Status zu sehen
~/monitor-ai-stack.sh

# Optional: Monitoring-Script als täglichen Cron-Job einrichten (8:00 morgens)
# (crontab -l 2>/dev/null; echo "0 8 * * * ~/monitor-ai-stack.sh >> /var/log/ai-stack-monitor.log 2>&1") | crontab -
```
*Dieses Script wird **täglich** oder bei Problemen ausgeführt für Systemüberwachung.*

### Watchtower Update-Management

```bash
# Watchtower-Status und verfügbare Updates prüfen (ohne Update durchzuführen)
docker run --rm \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --run-once --dry-run open-webui

# Alle Container-Images auf Updates prüfen
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" | head -10

# Update-Log-Datei überwachen (zeigt letzten Updates)
tail -20 /var/log/openwebui-updates.log

# Aktuell installierte OpenWebUI-Version anzeigen
docker inspect open-webui --format='{{.Config.Labels.version}}{{.Config.Labels.build_date}}'
```
*Diese Befehle helfen bei der **Update-Überwachung** und zeigen verfügbare Aktualisierungen.*

### Backup-Strategie

```bash
# Backup-Script erstellen
cat > ~/backup-ai-config.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/ai-stack-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up AI stack configuration to $BACKUP_DIR"

# Systemd-Services
sudo cp /etc/systemd/system/vllm-main.service "$BACKUP_DIR/"
sudo cp /etc/systemd/system/ollama.service "$BACKUP_DIR/"
sudo cp /etc/systemd/system/sd-forge.service "$BACKUP_DIR/"

# Credentials (verschlüsselt)
tar -czf "$BACKUP_DIR/credentials.tar.gz" -C ~/.ai-credentials .

# Docker-Konfigurationen
cp -r ~/docker "$BACKUP_DIR/"

# OpenWebUI-Daten
docker run --rm -v open-webui-data:/data -v "$BACKUP_DIR":/backup ubuntu \
    tar czf /backup/openwebui-data.tar.gz -C /data .

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x ~/backup-ai-config.sh
```

### Updates und Wartung

```bash
# Update-Script erstellen
cat > ~/update-ai-stack.sh << 'EOF'
#!/bin/bash
echo "Updating AI Stack..."

# System-Updates
sudo apt update && sudo apt upgrade -y

# Docker-Images aktualisieren
docker-compose -f ~/docker/openwebui/docker-compose.yml pull
docker-compose -f ~/docker/vllm-compose.yml pull

# Container neu starten
docker-compose -f ~/docker/openwebui/docker-compose.yml up -d
docker-compose -f ~/docker/vllm-compose.yml up -d

# Ollama-Modelle aktualisieren
ollama list | tail -n +2 | awk '{print $1}' | xargs -I {} ollama pull {}

echo "Update completed"
EOF

chmod +x ~/update-ai-stack.sh
```

## 13. Troubleshooting

### Häufige Probleme

#### Service startet nicht:
```bash
# Detaillierte Logs der letzten 50 Zeilen anzeigen
# Zeigt Fehlermeldungen beim Service-Start
sudo journalctl -u SERVICE_NAME -n 50 --no-pager

# Beispiel für vLLM-Service:
sudo journalctl -u vllm-gemma -n 50 --no-pager

# Dateiberechtigungen für Credentials prüfen
# User muss API-Key-Datei lesen können
ls -la ~/.ai-credentials/
sudo ls -la /home/aiservices/.ai-credentials/

# Service manuell starten um Fehler zu sehen
sudo systemctl start vllm-gemma
sudo systemctl status vllm-gemma  # Zeigt aktuellen Status
```
*Diese Befehle helfen bei der **Fehlerdiagnose** wenn Services nicht starten.*

#### GPU-Speicherprobleme (Gemma 3 benötigt ~16GB VRAM):
```bash
# GPU-Speicher und -Auslastung in Echtzeit überwachen
# Zeigt welche Prozesse GPU verwenden und wie viel VRAM belegt ist
watch -n 1 nvidia-smi

# Docker-Container-Ressourcenverbrauch anzeigen
# Zeigt CPU, RAM und GPU-Nutzung aller Container
docker stats

# Falls zu wenig VRAM: vLLM-Parameter in Systemd-Service anpassen
# Folgende Zeilen in /etc/systemd/system/vllm-gemma.service ändern:
# --max-model-len 2048 (statt 4096) = kürzerer Kontext
# --max-num-seqs 8 (statt 16) = weniger parallele Anfragen
# --gpu-memory-utilization 0.8 (statt 0.9) = weniger GPU-RAM nutzen

# Nach Änderungen Service neu laden:
sudo systemctl daemon-reload
sudo systemctl restart vllm-gemma
```
*Wird **bei Performance-Problemen** verwendet. GPU-Monitoring ist essentiell.*

#### Netzwerk-Verbindungsprobleme:
```bash
# Prüfen welche Prozesse auf welchen Ports lauschen
# Zeigt ob vLLM auf Port 8000 erreichbar ist
sudo netstat -tlnp | grep :8000

# Firewall-Status prüfen - zeigt alle geöffneten Ports
sudo ufw status

# Netzwerk-Konnektivität zwischen Containern testen
# Testet ob Container andere Services erreichen können
docker exec -it CONTAINER_NAME curl http://host.docker.internal:8000/health

# API-Funktionalität direkt testen
# Sendet Test-Anfrage an Gemma 3 Modell
curl -X POST "http://127.0.0.1:8000/v1/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(cat ~/.ai-credentials/main_api_key)" \
  -d '{"model": "gemma-3-12b", "prompt": "Test", "max_tokens": 10}'

# Erfolgreiche Antwort sollte JSON mit "choices" enthalten
```
*Diese Tests prüfen **API-Konnektivität** und **Service-Erreichbarkeit**.*

### Logs und Debugging

```bash
# Zentrales Logging einrichten
sudo tee /etc/rsyslog.d/50-ai-stack.conf > /dev/null << 'EOF'
# AI Stack Logs
:programname, startswith, "vllm" /var/log/ai-stack/vllm.log
:programname, startswith, "ollama" /var/log/ai-stack/ollama.log
& stop
EOF

sudo mkdir -p /var/log/ai-stack
sudo systemctl restart rsyslog

# Live-Monitoring aller Services
sudo journalctl -f -u vllm-gemma -u ollama -u sd-forge
```

### Gemma 3 Performance-Tuning

```bash
# GPU-spezifische Optimierungen in systemd-Service hinzufügen
# Diese Umgebungsvariablen verbessern GPU-Performance erheblich

# Für RTX 4090 (24GB VRAM): Maximale Performance-Konfiguration
# In /etc/systemd/system/vllm-gemma.service anpassen:
--max-model-len 8192              # Längere Kontexte möglich
--max-num-seqs 32                 # Viele parallele Anfragen
--max-num-batched-tokens 16384    # Große Batch-Größe
--gpu-memory-utilization 0.95     # Fast gesamten GPU-RAM nutzen

# Für RTX 3080/3090 (12-24GB VRAM): Ausgewogene Konfiguration
--max-model-len 4096              # Standard-Kontext
--max-num-seqs 16                 # Moderate parallele Anfragen
--max-num-batched-tokens 8192     # Standard-Batch-Größe
--gpu-memory-utilization 0.9      # 90% GPU-RAM

# Für RTX 3070 (8GB VRAM): Nicht empfohlen für Gemma 3 12B!
# Verwenden Sie stattdessen Gemma 3 8B oder kleinere Modelle:
# RedHatAI/gemma-3-8b-it-quantized.w8a8

# Erweiterte Performance-Umgebungsvariablen hinzufügen:
Environment="CUDA_LAUNCH_BLOCKING=0"        # Reduziert GPU-Overhead
Environment="CUDA_CACHE_DISABLE=0"          # Aktiviert CUDA-Kernel-Cache
Environment="VLLM_ATTENTION_BACKEND=FLASHINFER"  # Für RTX 30/40-Serie

# Nach Änderungen Service neu starten:
sudo systemctl daemon-reload
sudo systemctl restart vllm-gemma

# Performance überwachen:
nvidia-smi dmon -s pucvmet -d 2  # GPU-Metriken alle 2 Sekunden
```
*Diese Optimierungen werden **je nach GPU-Hardware** angepasst und erhöhen Durchsatz.*

## 14. Sicherheits-Checkliste

### Vor Produktivbetrieb prüfen:

- [ ] Alle `YOUR_*` Platzhalter durch echte Werte ersetzt
- [ ] Starke, eindeutige Passwörter und API-Keys generiert
- [ ] Firewall korrekt konfiguriert (nur notwendige Ports offen)
- [ ] Services laufen mit dedizierten Benutzern (nicht root)
- [ ] SSL/TLS für externe Zugriffe konfiguriert
- [ ] Backup-Strategie implementiert
- [ ] Monitoring und Logging aktiviert  
- [ ] Automatische Sicherheitsupdates aktiviert
- [ ] Fail2Ban für SSH konfiguriert
- [ ] Credentials niemals in Code/Logs committen

### SSL/TLS mit Let's Encrypt (Optional)

```bash
# Certbot installieren
sudo apt install -y certbot

# SSL-Zertifikat für OpenWebUI
sudo certbot certonly --standalone -d YOUR_DOMAIN.com

# Nginx als Reverse Proxy (Optional)
sudo apt install -y nginx
# Nginx-Konfiguration für SSL-Termination erstellen
```

---

**Erstellt:** $(date)  
**Version:** 2.1 (Security-Enhanced, Gemma 3, Updated Drivers)  
**Wartung:** Regelmäßige Updates erforderlich

⚠️ **WICHTIG:** Diese Konfiguration ist für Produktionsumgebungen optimiert. Alle Credentials müssen vor der Nutzung angepasst werden!

### Modell-Spezifikationen:
- **vLLM (Produktiv):** Gemma 3 12B INT8 (~16GB VRAM)
- **Ollama (Development):** jeffh/intfloat-multilingual-e5-large:q8_0 (RAG), gemma3:12b-it-qat
- **GPU-Treiber:** NVIDIA 570.x/575.x
- **CUDA:** 12.9 Update 1
- **Bildgenerierung:** ComfyUI mit FLUX.1-Kontext-Support
- **Telemetrie:** Langfuse für Forschungsanalyse