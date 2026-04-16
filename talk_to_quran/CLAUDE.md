# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo layout

Two loosely-coupled projects live side-by-side:

- `backend/` — Python Flask server implementing a Quran RAG chat API.
- `frontend/` — Flutter app (Android/iOS/web/desktop targets generated) that talks to the backend over HTTP. Firebase is used for auth only.
- `todo.txt` — the author's personal pre-demo checklist; reflects the intended runtime topology (Flask on `:8000` exposed via `ngrok`, Flutter pointed at the ngrok URL).

There is no shared build system. The two projects are run independently.

## Backend (`backend/app.py`)

### Running

```bash
cd backend
# Requires GROQ_API_KEY in backend/.env
python app.py           # Flask on 0.0.0.0:8000
```

There is **no `requirements.txt`**. Dependencies currently imported at top of `app.py`: `flask`, `flask-cors`, `python-dotenv`, `numpy`, `faiss-cpu`, `sentence-transformers`, `groq`, `requests`, `rank-bm25`, `beautifulsoup4`. If adding a dependency, prefer also creating a `requirements.txt` rather than adding more undeclared imports.

On first run the server builds a FAISS index over the full Quran translation (`quran_en.json` → ~6k verses with `all-mpnet-base-v2` embeddings) and persists it to `quran.index`. Subsequent starts reuse the cached index (~19 MB). Delete `quran.index` to force a rebuild after changing the embedding model or the source JSON.

### Request flow (`/chat`, POST)

The endpoint is stateless — the frontend sends the full chat history every turn. The server does the following in order:

1. **Classify** the latest user message as `SMALL_TALK`, `REFORMULATE`, or `QURANIC_SEARCH` via a Groq call (`classify_query`). Small talk returns a plain LLM reply and skips retrieval. `REFORMULATE` rewrites the query into a standalone question via `get_standalone_query`, then falls through to search — it does **not** early-return.
2. **Surah-name shortcut**: if any known surah transliteration appears in the query (substring match over `references`), retrieval is bypassed and the first 8 ayahs of that surah are returned directly. Only after this check does hybrid retrieval run.
3. **Hybrid retrieval** (`search_relevant_verses`): FAISS L2 semantic search + BM25 keyword search over the same verse corpus. FAISS distances are converted to similarity `1/(1+d)` and gated by a `threshold=1.5`; BM25 scores are max-normalized. Scores are summed per verse index and the top `k=TOP_K=3` are kept.
4. **Window expansion**: for each selected ayah, the previous and next ayahs in the *same surah* are added to the context set. Cross-surah neighbors are deliberately excluded.
5. **Per-ayah tafseer RAG** (`get_tafseer_rag`): for every retrieved ayah, the server fetches the Ibn Kathir tafseer (tafsir id `169`) from `api.quran.com`, strips HTML with BeautifulSoup, and caches the cleaned text on disk at `tafseer_cache/tafseer_{surah}_{ayah}.txt`. The cleaned text is then chunked (120 words), embedded, and a small in-memory FAISS index is built per ayah, memoized in the `tafseer_cache` dict (keyed `"surah:ayah"`). `search_tafseer` pulls the single most relevant chunk for the current query.
6. **Final answer**: Groq is called with a fixed system prompt + the last 4 history messages + a composed user prompt containing `CONTEXT` (verses) and `TAFSEER` (selected chunks). Response shape: `{"answer": str, "sources": [{"label", "text"}, ...]}`.

`GROQ_MODEL` and `EMBEDDING_MODEL` are top-of-file constants — change them there, not in individual call sites.

### Tafseer cache semantics

- File cache (`tafseer_cache/*.txt`) is the durable source of truth for tafseer text and survives restarts.
- The in-memory `tafseer_cache` dict holds the per-ayah FAISS index + chunks and is rebuilt lazily on first request after a restart.
- If you change `chunk_text`'s chunk size or the embedding model, the on-disk `.txt` files are still valid but any previously memoized in-memory indices go stale at process restart — no cache-bust needed beyond restarting.

## Frontend (`frontend/`)

Standard Flutter app. Common commands (run from `frontend/`):

```bash
flutter pub get
flutter run                      # hot-reload dev on connected device/emulator
flutter analyze                  # lint via analysis_options.yaml + flutter_lints
flutter test                     # run tests in test/
flutter test test/widget_test.dart   # single file
flutter build apk                # android release
```

### Architecture

- `main.dart` initializes Firebase (config in `firebase_options.dart`) and launches `AuthGate`.
- `AuthGate` (`lib/screens/auth_gate.dart`) shows `SplashScreen` for 2.5 s, then swaps to a `StreamBuilder` on `FirebaseAuth.authStateChanges()` — signed-in users see `ChatScreen`, others see `LoginScreen`. Firebase is the only auth source of truth; there is no server-side session.
- `AuthService` (`lib/services/auth_service.dart`) is a thin wrapper around `FirebaseAuth` (email/password + sign out + auth stream).
- `ChatScreen` owns the conversation list (`_messages`, newest-first, rendered with `reverse: true`). On send it POSTs `{question, history}` to the backend, where `history` is built by iterating `_messages.reversed.skip(1)` and prepending a fixed system prompt — i.e. **the frontend constructs the full history on every turn**; the backend keeps no session state. Bot replies are animated word-by-word via `_animateBotResponse`.

### Backend URL is hardcoded

`_apiUrl` in `lib/screens/chat_screen.dart` is a hardcoded ngrok `https://...ngrok-free.dev/chat` URL and changes every time ngrok is restarted. The request also sends `ngrok-skip-browser-warning: 69420` to bypass ngrok's interstitial — keep this header when editing the request. For emulator-local testing against a laptop backend, use `10.0.2.2:8000` (Android emulator) instead of localhost.
