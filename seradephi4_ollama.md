# 🚀 Anleitung: Finetuned Phi-4 Modell in Ollama mit 16.000 Tokens Kontextfenster

Diese Anleitung beschreibt, wie du dein finetuned Phi-4 Modell `serade_v01_entscheider.Q4_K_M.gguf` in **Ollama** unter dem Namen **SeradePhi4** einbindest und das volle Kontextfenster von **16.000 Tokens** nutzt.

---

## 📌 1. Verzeichnisstruktur anlegen
Lege ein neues Verzeichnis für dein Modell an:

```bash
mkdir seradephi4 && cd seradephi4
```

Platziere folgende Dateien im Verzeichnis:

```
seradephi4/
├── Modelfile
└── serade_v01_entscheider.Q4_K_M.gguf
```

---

## 📝 2. Modelfile erstellen

Erstelle die Datei `Modelfile` mit folgendem Inhalt:

```
FROM phi4

# Name des Models
NAME SeradePhi4

# Lade das GGUF-Modell
PARAMETER gguf serade_v01_entscheider.Q4_K_M.gguf

# Setze das maximale Kontextfenster auf 16.000 Tokens
PARAMETER num_ctx 16000

# Setze Stop-Tokens
PARAMETER stop [
    "<|im_start|>",
    "<|im_end|>",
    "<|im_sep|>"
]

# Model Prompt Template für Phi4
TEMPLATE """
{{- range $i, $_ := .Messages }}
{{- $last := eq (len (slice $.Messages $i)) 1 -}}
<|im_start|>{{ .Role }}<|im_sep|>
{{ .Content }}{{ if not $last }}<|im_end|>
{{ end }}
{{- if and (ne .Role "assistant") $last }}<|im_end|>
<|im_start|>assistant<|im_sep|>
{{ end }}
{{- end }}
"""

# Setze Sampling-Parameter (Optional)
PARAMETER mirostat 2
```

---

## 📥 3. Modell in Ollama laden

Führe folgenden Befehl aus, um das Modell in Ollama zu registrieren:

```bash
ollama create SeradePhi4 -f Modelfile
```

Falls du sichergehen möchtest, dass dein Modell korrekt geladen wurde, überprüfe es mit:

```bash
ollama show SeradePhi4
```

**Achte darauf, dass `num_ctx: 16000` angezeigt wird!** Falls eine niedrigere Zahl steht, editiere die `Modelfile` erneut und lade das Modell neu.

---

## 🏗️ 4. Modell testen

Teste das Modell mit einem einfachen Prompt:

```bash
ollama run SeradePhi4 "Was ist der Sinn des Lebens?"
```

Oder mit einem Test, der das volle Kontextfenster prüft:

```bash
ollama run SeradePhi4 "Erinnere dich an diesen Satz: 'KI in der Lehre verändert die Hochschulbildung.' Was habe ich dir gesagt?"
```

---

## 🔧 5. Optionale Einstellungen

Falls du das Modell in einer laufenden Ollama-Instanz nutzen möchtest:

```bash
ollama serve
```

Dadurch wird Ollama als API-Dienst bereitgestellt und dein Modell ist über eine API ansprechbar.

---

## ✅ Fazit

- Dein **finetuned Phi-4 Modell** ist nun in **Ollama** registriert.
- Es nutzt das **volle Kontextfenster von 16.000 Tokens**.
- Die Modellparameter und das Prompt-Template sind korrekt integriert.
- Du kannst das Modell direkt über **Ollama CLI oder API** verwenden.

Falls du Änderungen am Modell oder den Parametern vornimmst, denke daran, das Modell neu zu registrieren mit:

```bash
ollama create SeradePhi4 -f Modelfile
```

🚀 Viel Erfolg mit deinem **SeradePhi4 Modell**! 🎯
