# Einrichtung eines GPU-Servers zur Bereitstellung eines On-Premise-Sprachmodells mittels OpenWebUI

## 0. Firewallrichtlinien anpassen

Wir benötigen folgende geöffnete Ports:

- **Port 80**: Für OpenWebUI, die ChatUI
- **Port 11434**: Für Ollama, den Bereitsteller von Embedding-Modellen u. w.
- **Port 8000**: Für vLLM, den Bereitsteller des 1. Produktiv-Sprachmodells. Bei weiteren auch noch die Ports 8001, ...
- **Port 4000**: Für die SearXNG Metasuchmaschine
- **Port 3001**: Für Perplexica Backend (muss nicht nach außen freigegeben werden)
- **Port 3000**: Für Perplexica
- **Port 7870**: Für StableDiffusion Forge - das Bilderstellungsbereitstellungsprogramm
- **Port 9099**: Für Pipeline-Docker von OpenWebUI (muss nicht nach außen freigegeben werden)

## 1. Installation relevanter OS-Updates und Tools

### Aktualisierung des Systems
```bash
sudo apt update && sudo apt upgrade -y
```
Stellt sicher, dass das Betriebssystem auf dem neuesten Stand ist.

### Installation von grundlegenden Tools
```bash
sudo apt install -y build-essential wget curl git htop
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
- `-b`: Aktiviert den Batch-Modus (kein Eingreifen erforderlich).
- `-p $HOME/miniconda3`: Gibt den Installationspfad an.

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
sudo apt install -y nvidia-driver-550
sudo reboot
```

### GPU-Status überprüfen
```bash
nvidia-smi
```

## 4. Installation des CUDA-Toolkits

### Download und Installation (im Falle von Ubuntu 22.04)
```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-6
```

### Download und Installation (im Falle von Ubuntu 24.04)
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
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
```

### Installation des CUDA-Container-Toolkits
```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
sudo systemctl restart containerd
```

### Installation von Docker Compose
```bash
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### Installation testen
```bash
docker-compose --version
```

## 6. Installation von OpenWebUI und des Codeinterpreters

### OpenWebUI ohne Codeinterpreter
```bash
docker run -d -p 80:8080 -e OLLAMA_BASE_URL=http://127.0.0.1:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```

### OpenWebUI mit Codeinterpreter und Ollama
In folgendem Container wird die Nutzung des Codeinterpreters ermöglicht. Die Option `-v /var/run/docker.sock:/var/run/docker.sock` ermöglicht den Zugang zum Docker-Socket.

```bash
docker run -d -p 80:8080 -e OLLAMA_BASE_URL=http://127.0.0.1:11434 -v open-webui:/app/backend/data -v /var/run/docker.sock:/var/run/docker.sock --add-host=host.docker.internal:host-gateway --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```

### Codeinterpreter Container

1. **Dockerfile und requirements speichern**

   Erstellen Sie die benötigten Dateien und Verzeichnisse:
   ```bash
   cd docker
   mkdir ouitools
   cd ouitools
   ```

   **Dockerfile erstellen:**
   ```bash
   nano Dockerfile
   ```
   Inhalt des Dockerfile:
   ```dockerfile
   FROM python:3.11

   RUN apt-get update
   COPY requirements.txt .
   RUN pip install --no-cache-dir -r requirements.txt
   RUN apt-get install -y gnuplot
   RUN apt-get install -y poppler-utils

   CMD ["python", "/tmp/app.py"]
   ```
   Speichern mit `Strg+O` und `Strg+X`.

   **requirements.txt erstellen:**
   ```bash
   nano requirements.txt
   ```
   Inhalt der requirements.txt:
   ```
   pandas
   numpy
   scipy
   py-gnuplot
   statsmodels
   scikit-learn
   matplotlib
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
   seaborn
   ```
   Speichern und schließen mit `Strg+O` und `Strg+X`.

2. **Image erstellen**

   Bauen Sie ein Docker-Image aus der `Dockerfile`:
   ```bash
   docker build -t pythontool .
   ```

3. **Tool in OpenWebUI hinzufügen**

   Nach Erstellung des Containers können Sie das Tool in OpenWebUI integrieren. Folgen Sie dabei den Anweisungen in der OpenWebUI-Dokumentation zur Tool-Integration. Das Tool findet sich hier: [https://openwebui.com/t/smonux/dockerinterpreter/](https://openwebui.com/t/smonux/dockerinterpreter/)

### Bereitstellen von Pipelines

   Für eine vereinfachte Einrichtung mit Docker:

   **Pipelines-Container starten:**
   ```bash
   docker run -d -p 9099:9099 --add-host=host.docker.internal:host-gateway -v pipelines:/app/pipelines --name pipelines --restart always ghcr.io/open-webui/pipelines:main
   ```

   **Verbindung zu Open WebUI herstellen:**

   1. Navigieren Sie zum **Administrationsbereich > Einstellungen > Verbindungen** in Open WebUI.
   2. Drücken Sie auf der Seite die **+**-Taste, um eine weitere Verbindung hinzuzufügen.
   3. Geben Sie folgende Einstellungen ein:
      - **API-URL**: `http://host.docker.internal:9099`
      - **API-Schlüssel**: `0p3n-w3bu!`

## 7. Bereitstellung der generative aber auch embedding-Modelle



## 7.1 Bereitstellung durch SG-LANG

### Start von vLLM (Llama3.1 8B mit int4)
```bash
docker run --gpus all --shm-size 32g -p 8000:8000 -v /root/docker/sglang/huggingface_cache:/root/.cache/huggingface --env "HF_TOKEN=<Ihr_HF_Token>" --ipc=host lmsysorg/sglang:latest python3 -m sglang.launch_server --model-path hugging-quants/Meta-Llama-3.1-8B-Instruct-AWQ-INT4 --api-key sk-12j12hdwjk23jdhj28dwj --host 0.0.0.0 --port 8000
```


## 7.2 Bereitstellung von vLLM

### Docker-Image von vLLM ziehen
```bash
docker pull vllm/vllm-openai:latest
mkdir -p /root/.cache/huggingface
```

### Start von vLLM (Llama3.1 8B mit fp8)
```bash
docker run --gpus all --restart unless-stopped -p 8000:8000 -v /root/.cache/huggingface:/root/.cache/huggingface -e HF_HUB_ENABLE_HF_TRANSFER=1 --name vllm_openai_server vllm/vllm-openai:latest --model neuralmagic/Meta-Llama-3.1-8B-Instruct-FP8 --max-model-len 4096 --port 8000 --api-key sk-12j12hdwjk23jdhj28dwj --max_num_seqs 8 --max_num_batched_tokens 32768 --max_parallel_loading_workers 3 --gpu-memory-utilization 1.0
```

### Start von vLLM (Llama3.1 8B mit int4)
```bash
docker run --runtime nvidia --gpus all --restart unless-stopped --ipc=host -p 8000:8000 -v /root/.cache/huggingface:/root/.cache/huggingface -e HF_HUB_ENABLE_HF_TRANSFER=1 --name vllm_openai_server vllm/vllm-openai:latest --model hugging-quants/Meta-Llama-3.1-8B-Instruct-AWQ-INT4 --max-model-len 4096 --port 8000 --api-key sk-12j12hdwjk23jdhj28dwj --max_num_seqs 8 --max_num_batched_tokens 32768 --max_parallel_loading_workers 3 --gpu-memory-utilization 1.0
```

### Start von vLLM (Multimodales Modell Llama3.2 Vision mit fp8)
```bash
docker run -d --gpus all --restart unless-stopped -p 8000:8000 -v /root/.cache/huggingface:/root/.cache/huggingface -e HF_HUB_ENABLE_HF_TRANSFER=1 --name vllm_openai_server_fp8 vllm/vllm-openai:latest --model neuralmagic/Llama-3.2-11B-Vision-Instruct-FP8-dynamic --enforce-eager --max-num-seqs 3 --limit-mm-per-prompt "image=1" --max-model-len 2048 --port 8000 --api-key sk-12j12hdwjk23jdhj28dwj --gpu-memory-utilization 1.0
```

## 8. Einrichtung von SearXNG (Alternativ Perplexica in 9. installieren und dann nicht SearXNG hier)

### Konfiguration anpassen
```bash
cd docker
cd searxng
nano settings.yml
```

### Beispielkonfiguration
```yaml
use_default_settings: true

server:
  secret_key: "f9e603d4191caab069b021fa0568391a33c8a837b470892c64461b5dd12464f4"
  limiter: false
  image_proxy: true
  port: 8080
  bind_address: "0.0.0.0"

ui:
  static_use_hash: true

search:
  safe_search: 0
  autocomplete: ""
  default_lang: ""
  formats:
    - html
    - json
```

### SearXNG Container starten
```bash
docker run -d --name searxng -e BASE_URL=http://localhost:8001 -e SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml -v /root/docker/searxng/settings.yml:/etc/searxng/settings.yml -p 8001:8080 searxng/searxng
```

## 9. Installation von Perplexica

### 1. Repository klonen
Navigieren Sie in das Verzeichnis `docker` und klonen Sie das Perplexica-Repository:
```bash
cd docker
git clone https://github.com/ItzCrazyKns/Perplexica.git
```

### 2. Konfigurationsdateien anpassen

#### 2.1 `config.toml`
Bearbeiten Sie die Datei `config.toml` im geklonten Repository:
```bash
nano Perplexica/config.toml
```

Inhalt der Datei `config.toml`:
```toml
[API_KEYS]
OPENAI = ""
GROQ = ""
ANTHROPIC = ""
GEMINI = ""

[API_ENDPOINTS]
OLLAMA = "http://<IP DES SERVERS>:11434"
SEARXNG = "http://localhost:4000"

[GENERAL]
PORT = 3001
SIMILARITY_MEASURE = "cosine"
KEEP_ALIVE = "5m"
```
- Ersetzen Sie `<IP DES SERVERS>` durch die tatsächliche IP-Adresse des Servers.
- Fügen Sie die entsprechenden API-Schlüssel in den Abschnitt `[API_KEYS]` ein.
- Passen Sie die API-Endpunkte nach Bedarf an.
- Speichern Sie die Datei mit `Strg+O` und schließen Sie sie mit `Strg+X`.

#### 2.2 `docker-compose.yaml`
Bearbeiten Sie die Datei `docker-compose.yaml`:
```bash
nano Perplexica/docker-compose.yaml
```

Inhalt der Datei `docker-compose.yaml`:
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
        - NEXT_PUBLIC_API_URL=http://<IP DES SERVERS>:3001/api
        - NEXT_PUBLIC_WS_URL=ws://<IP DES SERVERS>:3001
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
- Ersetzen Sie `<IP DES SERVERS>` durch die tatsächliche IP-Adresse des Servers.
- Speichern Sie die Datei mit `Strg+O` und schließen Sie sie mit `Strg+X`.
https://github.com/ItzCrazyKns/Perplexica?tab=readme-ov-file#ollama-connection-errors

https://github.com/ItzCrazyKns/Perplexica/blob/master/docs/installation/NETWORKING.md

https://github.com/open-webui/open-webui/discussions/4269
oder

https://openwebui.com/f/gwaanl/perplexica_pipe


### 3. Docker-Container starten

Bleiben Sie im Verzeichnis und starten Sie die Container:
```bash
docker-compose up -d
```

### 4. Zugriff auf Perplexica
Nach dem Start ist Perplexica erreichbar unter:
- `http://localhost:3000`
- oder `http://<IP DES SERVERS>:3000` (bei Zugriff von einem anderen Gerät).

## 10. Installation von Stable Diffusion Forge

### Installation von Stable Diffusion Forge
```bash
git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git
cd stable-diffusion-webui-forge

conda create --name sd-forge python=3.10
conda activate sd-forge
pip install -r requirements.txt
./webui.sh --listen --port 7870 --share --api --api-auth :qwe123
```

### Anpassungen in `webui.sh`
Kommentieren Sie die Root-Bedingung aus:
```bash
# if [ "$EUID" -eq 0 ]; then
#   echo "This script must not be launched as root, aborting..."
#   exit 1
# fi
```

### Herunterladen des FLUX-Modells
```bash
cd ~/docker/stable-diffusion-webui-forge/models/Stable-diffusion
wget -O flux1-dev-bnb-nf4.safetensors "https://huggingface.co/lllyasviel/flux1-dev-bnb-nf4/resolve/main/flux1-dev-bnb-nf4.safetensors"
```

### Herunterladen des Stable Diffusion XL-Modells
```bash
cd ~/docker/stable-diffusion-webui-forge/models/Stable-diffusion
wget -O juggernautXL_v8Rundiffusion.safetensors "https://huggingface.co/RunDiffusion/Juggernaut-XL-v8/resolve/main/juggernautXL_v8Rundiffusion.safetensors"
```

### Automatisches Starten von Stable Diffusion Forge nach dem Booten

#### 1. Systemd-Dienst erstellen

Erstelle eine neue Datei für den Systemd-Dienst:

```bash
sudo nano /etc/systemd/system/sd-forge.service
```

##### Inhalt der Datei
Hier ist die Konfiguration des Dienstes. Ersetze `<pfad>` durch den Pfad zu deinem Stable Diffusion Forge-Verzeichnis.

```ini
[Unit]
Description=Stable Diffusion Forge Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/docker/stable-diffusion-webui-forge
ExecStart=/bin/bash -c "source /root/miniconda3/etc/profile.d/conda.sh && conda activate sd-forge && ./webui.sh --listen --port 7870 --share --api --api-auth matmax:dimpwffufuk8le --gradio-auth matmax:dimpwffufuk8le"
Restart=always
Environment="PATH=/root/miniconda3/envs/sd-forge/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
```

#### 2. Systemd-Dienst aktivieren und starten

Speichere die Datei und führe folgende Befehle aus:

```bash
sudo systemctl daemon-reload
sudo systemctl enable sd-forge.service
sudo systemctl start sd-forge.service
```

#### 3. Status des Dienstes überprüfen

Prüfe, ob der Dienst korrekt läuft:

```bash
systemctl status sd-forge.service
```

#### 4. Logs anzeigen

Falls Probleme auftreten, können die Logs des Dienstes eingesehen werden:

```bash
journalctl -u sd-forge.service
```

---

#### Hinweise

- **Pfad zu Miniconda**: Der Miniconda-Pfad ist `/root/miniconda3`.
- **Stable Diffusion Forge Pfad**: Stelle sicher, dass `<pfad>` im Systemd-Dienst durch den tatsächlichen Pfad zu deinem Stable Diffusion Forge-Verzeichnis ersetzt wird.
- **Benutzer root**: Der Dienst läuft als root. Falls dies geändert werden soll, erstelle einen dedizierten Benutzer und passe den `User`-Eintrag entsprechend an.
- **Gradio-Authentifizierung**: Ersetze `user:password` durch den gewünschten Benutzernamen und das Passwort für die Authentifizierung.
- **Fehlermeldungen**: Überprüfe die Logs, wenn der Dienst nicht startet, um mögliche Probleme zu diagnostizieren.

Mit dieser Konfiguration sollte Stable Diffusion Forge automatisch nach dem Booten des Systems gestartet werden.


## 11. Installation und Nutzung von Ollama

Mit Ollama können Omnimodal-Modelle und Embeddingmodelle bei hoher Qualität und Stabilität schnell und ressourcenschonend eingebunden werden. Dafür muss zunächst das Modell geladen werden. Danach ein paar Anpassungen an der Systemdatei und entsprechende Modelle gepullt werden.

### Installation von Ollama
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Modelle beziehen
- **Modell Llama3.2-vision beziehen**:
  ```bash
  ollama pull llama3.2-vision
  ```
- **SOTA-Embeddingmodell von IBM**:
  ```bash
  ollama pull granite-embedding:278m
  ```
- **SOTA-Visionmodell(e)**:
  ```bash
  ollama pull minicpm-v
  ```
- **SOTA genAI Modell Phi-4**:
  ```bash
  ollama pull phi4
  ```

### Nützliche Ollama-Befehle

- **Verfügbare Modelle anzeigen**:
  ```bash
  ollama list
  ```
- **Laufende Server überprüfen**:
  ```bash
  ollama ps
  ```
- **Server starten**:
  ```bash
  ollama serve
  ```
- **Ein Modell ausführen**:
  ```bash
  ollama run llama3.2-vision --verbose
  ```
- **Neustart von Ollama**:
  Starten Sie den Ollama-Service neu:
  ```bash
  sudo systemctl daemon-reload
  sudo systemctl restart ollama
  ```

### Konfiguration der ollama.service-Datei

1. Öffnen Sie die Service-Datei:
   ```bash
   sudo nano /etc/systemd/system/ollama.service
   ```

2. Fügen Sie die folgende Konfiguration ein:
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
   Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"
   Environment="OLLAMA_HOST=0.0.0.0"
   Environment="OLLAMA_MAX_LOADED_MODELS=5" # Maximale Anzahl gleichzeitig geladener Modelle
   Environment="OLLAMA_NUM_PARALLEL=6" # Maximale Anzahl paralleler Requests pro Modell
   Environment="OLLAMA_MAX_QUEUE=256" # Maximale Anzahl an Warteschlangen-Requests

   [Install]
   WantedBy=default.target
   ```

3. Laden Sie die Änderungen neu und starten Sie den Dienst:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart ollama
   ```

## 12. Einstellungen für OpenWebUI

### 1. Wo sind meine Dateien?

Um den Speicherort der Dateien zu finden, führen Sie den folgenden Befehl aus:
```bash
docker volume inspect open-webui
```

Die Dateien befinden sich auf dem Server unter:
```
/var/lib/docker/volumes/open-webui/_data
```

Genauer gesagt, sind sie im Verzeichnis `uploads` zu finden.

### 2. Aktualisieren von OpenWebUI

Um die lokale Docker-Installation auf die neueste Version zu aktualisieren, können Sie Watchtower verwenden. Führen Sie dazu den folgenden Befehl aus:
```bash
docker run --rm --volume /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --run-once open-webui
```

> **Hinweis:** Ersetzen Sie im letzten Teil des Befehls `open-webui` durch den Namen Ihres Containers, falls dieser anders lautet.

## 3. Einstellungen in OpenWebUI

### Modellverbindungen einrichten

1. Navigieren Sie zu:
   **Benutzer > Administrationsbereich > Einstellungen > Verbindungen**
2. Starten Sie die OpenAI API und geben Sie folgende Informationen ein:
   - **URL**: `http://85.215.141.141:8000/v1`
   - **Schlüssel**: `sk-test-1234567890abcdef`
3. Starten und speichern Sie die Einstellungen.

### Ollama-Verbindung aktivieren

1. Starten Sie Ollama und konfigurieren Sie die Verbindung mit folgenden Einstellungen:
   - **URL**: `http://localhost:11434`

Speichern Sie die Änderungen, um die Verbindungen zu nutzen.

### Modelle anpassen

Auf der Seite **Modelle** können die Basismodelle angepasst werden, inklusive:
- Name
- Bild
- Standardfähigkeiten
- Weitere Optionen

### Embedding-Modell auswählen

1. Navigieren Sie zu **Dokumente** und wählen Sie das Embedding-Modell aus.
2. Geben Sie folgende Einstellungen ein:
   - **Embedding-Modell-Engine**: Ollama
   - **URL**: `http://127.0.0.1:11434`
   - **Stapelgröße**: 16
   - **Embedding-Modell**: `granite-embedding:278m`
   - **Top K**: 5
   - **Blockgröße**: 800
   - **Blocküberlappung**: 100

Speichern Sie die Änderungen, um das Embedding-Modell zu verwenden.

### Websuche anpassen

1. Navigieren Sie zu den Websucheinstellungen.
2. Aktivieren Sie die Websuche und konfigurieren Sie folgende Parameter:
   - **Websuche aktivieren**: Ja
   - **Suchmaschine**: SearxNG
   - **SearxNG-Abfrage-URL**: `http://kaepsele.hfwu.de:4000/search?q=<query>`
   - **Anzahl Suchergebnisse**: 3-5
   - **Anzahl gleichzeitiger Anfragen**: 10

Speichern Sie die Änderungen, um die Websuche zu nutzen.

### Bildererstellung aktivieren

1. Navigieren Sie zu den Einstellungen für die Bildgenerierung.
2. Aktivieren Sie die Bildgenerierung und konfigurieren Sie folgende Parameter:
   - **Bildgenerierungs-Engine**: Automatic1111
   - **AUTOMATIC1111-Basis-URL**: `http://kaepsele.hfwu.de:7870/`
   - **AUTOMATIC1111-API-Authentifizierungszeichenfolge**: `matmax:dimpwffufuk8le`

Speichern Sie die Änderungen, um die Bilderstellung zu nutzen.
