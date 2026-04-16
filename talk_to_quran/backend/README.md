# Backend

Flask server that powers the Quran Q&A chat. Single file: `app.py`.

## Setup

```bash
# from backend/
python -m venv .venv
source .venv/Scripts/activate        # Git Bash on Windows
# or: .venv\Scripts\activate         # cmd/PowerShell

pip install flask flask-cors python-dotenv numpy faiss-cpu \
            sentence-transformers groq requests rank-bm25 beautifulsoup4
```

Create `backend/.env`:

```
GROQ_API_KEY=your_key_here
```

## Run

```bash
python app.py        # listens on 0.0.0.0:8000
```

The first start builds a FAISS index over `quran_en.json` using `all-mpnet-base-v2` embeddings and writes it to `quran.index` (~19 MB). Later starts reuse the cached index — delete `quran.index` to force a rebuild after changing the embedding model or the source JSON.

## Exposing to a phone via ngrok

The Flutter client usually runs on a physical device, so the backend is tunneled through ngrok:

```bash
ngrok http 8000
```

Copy the `https://...ngrok-free.dev` URL and set it as `_apiUrl` in `frontend/lib/screens/chat_screen.dart` (append `/chat`). The URL changes every time ngrok restarts.

## API

### `POST /chat`

Request:

```json
{
  "question": "What does the Quran say about patience?",
  "history": [
    {"role": "system", "content": "..."},
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

The server is stateless — the client must send the entire conversation history every turn.

Response:

```json
{
  "answer": "…model answer with [Surah:Ayah] citations…",
  "sources": [
    {"label": "Surah 2 (Al-Baqarah), Ayah 153", "text": "…"}
  ]
}
```

## Pipeline

1. **Classify** the latest message as `SMALL_TALK`, `REFORMULATE`, or `QURANIC_SEARCH`. Small talk skips retrieval. `REFORMULATE` rewrites the question into a standalone form and falls through to search.
2. **Surah-name shortcut** — if a known surah transliteration appears in the query, return the first 8 ayahs of that surah directly.
3. **Hybrid retrieval** — FAISS L2 semantic search + BM25 keyword search over the same verse corpus. FAISS distances are converted to similarity `1/(1+d)` (gated by `threshold=1.5`); BM25 scores are max-normalized; scores are summed per verse. Top `k=3` kept.
4. **Window expansion** — for each hit, include the previous and next ayahs from the same surah.
5. **Tafseer RAG** — for each retrieved ayah, fetch Ibn Kathir tafseer (tafsir id `169`) from `api.quran.com`, strip HTML, cache to `tafseer_cache/tafseer_{surah}_{ayah}.txt`, then chunk/embed/FAISS-search per-ayah to pull the single most relevant chunk for the query.
6. **Generate** — Groq (`llama-3.1-8b-instant`) composes the final answer from verses + tafseer + last 4 history messages.

## Tuning knobs

Top of `app.py`:

- `EMBEDDING_MODEL` — sentence-transformers model name.
- `GROQ_MODEL` — Groq chat model.
- `TOP_K` — number of ayahs retrieved before window expansion.

Changing the embedding model requires deleting `quran.index`.
