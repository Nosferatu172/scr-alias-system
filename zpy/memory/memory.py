import json
from pathlib import Path
from datetime import datetime

MEMORY_FILE = Path("evolve/memory_index.json")

# --------------------------------------------------

# SCORING ENGINE

# --------------------------------------------------

def score_event(event):
"""
Assigns a value score to an event
"""

```
data = event.get("data", {})

impact = 0
novelty = 0
reuse = 0

# ---- impact ----
if data.get("duplicate_groups", 0) > 10:
    impact += 0.4
if data.get("near_duplicates", 0) > 20:
    impact += 0.3

# ---- novelty ----
if data.get("new_patterns"):
    novelty += 0.5

# ---- reuse potential ----
if data.get("functions", 0) > 50:
    reuse += 0.4

score = round(min(impact + novelty + reuse, 1.0), 3)

return {
    "score": score,
    "impact": impact,
    "novelty": novelty,
    "reuse": reuse
}
```

# --------------------------------------------------

# MEMORY STORE

# --------------------------------------------------

def load_memory():
if MEMORY_FILE.exists():
try:
return json.loads(MEMORY_FILE.read_text())
except:
return []
return []

def save_memory(data):
MEMORY_FILE.parent.mkdir(parents=True, exist_ok=True)
MEMORY_FILE.write_text(json.dumps(data, indent=2))

def store_event(event):
memory = load_memory()

```
scored = score_event(event)

entry = {
    "timestamp": datetime.utcnow().isoformat(),
    "event": event.get("event"),
    "score": scored,
    "summary": summarize_event(event)
}

memory.append(entry)

save_memory(memory)
```

# --------------------------------------------------

# SUMMARIZATION

# --------------------------------------------------

def summarize_event(event):
data = event.get("data", {})

```
return {
    "functions": data.get("functions"),
    "duplicates": data.get("duplicate_groups"),
    "near_duplicates": data.get("near_duplicates")
}
```

# --------------------------------------------------

# PRUNING

# --------------------------------------------------

def prune_memory(threshold=0.2, max_entries=5000):
memory = load_memory()

# remove low-value entries
memory = [m for m in memory if m["score"]["score"] >= threshold]

```
# trim size
memory = sorted(memory, key=lambda x: x["score"]["score"], reverse=True)
memory = memory[:max_entries]

save_memory(memory)

return len(memory)
```
