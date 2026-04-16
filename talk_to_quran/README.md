# Talk to Quran

A Quran Q&A chat app. Ask a question in plain English and get an answer grounded in relevant ayahs and their tafseer, with citations.

- **`backend/`** — Python Flask server. Retrieves verses with a hybrid FAISS + BM25 search, fetches Ibn Kathir tafseer from the quran.com API, and generates the final answer via Groq.
- **`frontend/`** — Flutter app (Android / iOS / web / desktop). Firebase Auth for sign-in, chat UI that talks to the backend over HTTP.

See each subproject's README for setup and run instructions.

## How it works

1. Flutter client sends the user's question and the full chat history to the Flask `/chat` endpoint.
2. The server classifies the message (small talk / reformulate / search).
3. For search queries, it runs hybrid retrieval over the Quran translation, expands the result window to include neighboring ayahs, fetches and caches tafseer for each, and retrieves the most relevant tafseer chunks.
4. Groq composes the final answer from verses + tafseer + recent history. The client renders it with a typewriter animation.

## Quick start

Run the backend and the Flutter app in two terminals.

```bash
# 1. Backend
cd backend
# put GROQ_API_KEY=... in backend/.env
python app.py

# 2. Frontend
cd frontend
flutter pub get
flutter run
```

The Flutter client expects the backend reachable at the URL hardcoded in `frontend/lib/screens/chat_screen.dart` (currently an ngrok tunnel). Update `_apiUrl` to match your setup — e.g. `http://10.0.2.2:8000/chat` for the Android emulator.

## Repo layout

```
talk_to_quran/
├── backend/          # Flask + RAG server
├── frontend/         # Flutter app
├── CLAUDE.md         # guidance for Claude Code
└── README.md
```
