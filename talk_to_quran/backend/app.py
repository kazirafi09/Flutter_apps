import json
import os
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer
from groq import Groq
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv
import requests
from rank_bm25 import BM25Okapi
from bs4 import BeautifulSoup

load_dotenv()

# =========================================================
# 1. INITIALIZATION (Runs once when server starts)
# =========================================================

print("\n--- Initializing Quran RAG Server ---\n")

# CONFIGURATION
QURAN_JSON_PATH = "quran_en.json"
FAISS_INDEX_PATH = "quran.index"
EMBEDDING_MODEL = "all-mpnet-base-v2"
GROQ_MODEL = "llama-3.1-8b-instant"
TOP_K = 3
tafseer_cache = {}

TAFSEER_DIR = "tafseer_cache"
os.makedirs(TAFSEER_DIR, exist_ok=True)
# ---------------------------------------------------------
# Initialize Groq Client
# ---------------------------------------------------------

groq_api_key = os.environ.get("GROQ_API_KEY")
if not groq_api_key:
    raise EnvironmentError("FATAL: GROQ_API_KEY environment variable not set.")

client = Groq(api_key=groq_api_key)

# ---------------------------------------------------------
# Load Embedding Model
# ---------------------------------------------------------

model = SentenceTransformer(EMBEDDING_MODEL)

def chunk_text(text, chunk_size=120):
    words = text.split()
    chunks = []

    for i in range(0, len(words), chunk_size):
        chunk = " ".join(words[i:i + chunk_size])
        chunks.append(chunk)

    return chunks

def embed_chunks(chunks):
    embeddings = model.encode(chunks, show_progress_bar=False)
    return np.array(embeddings).astype("float32")


def build_tafseer_index(chunks, embeddings):
    dimension = len(embeddings[0])
    index = faiss.IndexFlatL2(dimension)

    index.add(np.array(embeddings).astype("float32"))

    return index

def search_tafseer(query, index, chunks, top_k=3):
    query_embedding = model.encode([query])
    query_embedding = np.array(query_embedding).astype("float32")

    D, I = index.search(query_embedding, top_k)

    return [chunks[i] for i in I[0]]


import requests

def fetch_tafseer(surah_id, ayah_id):
    tafseer_file = os.path.join(
        TAFSEER_DIR,
        f"tafseer_{surah_id}_{ayah_id}.txt"
    )

    # 1️⃣ If already cached
    if os.path.exists(tafseer_file):
        with open(tafseer_file, "r", encoding="utf-8") as f:
            return f.read()

    # 2️⃣ Download
    url = f"https://api.quran.com/api/v4/tafsirs/169/by_ayah/{surah_id}:{ayah_id}"

    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        print("API error:", e)
        return "Tafseer temporarily unavailable."

    # 3️⃣ Extract safely
    tafseer_text = (
        data.get("tafsir", {}).get("text")
        or (data.get("tafsirs") or [{}])[0].get("text")
    )

    if not tafseer_text:
        print("Unexpected JSON structure:", data)
        return "Tafseer format not recognized."

    # 4️⃣ 🔥 Clean HTML (LAST tra
    import re

    soup = BeautifulSoup(tafseer_text, "html.parser")
    tafseer_text = soup.get_text(separator=" ", strip=True)
    tafseer_text = re.sub(r"\s+", " ", tafseer_text).strip()

    # 5️⃣ Save CLEAN text
    with open(tafseer_file, "w", encoding="utf-8") as f:
        f.write(tafseer_text)

    return tafseer_text
 
def get_tafseer_rag(surah_id, ayah_id):
    key = f"{surah_id}:{ayah_id}"

    # If already built, return cached
    if key in tafseer_cache:
        return tafseer_cache[key]

    tafseer_text = fetch_tafseer(surah_id, ayah_id)

    if not tafseer_text or tafseer_text.startswith("Tafseer not"):
        return None

    chunks = chunk_text(tafseer_text)
    embeddings = embed_chunks(chunks)

    dimension = embeddings.shape[1]
    index = faiss.IndexFlatL2(dimension)
    index.add(embeddings)

    tafseer_cache[key] = {
        "index": index,
        "chunks": chunks
    }

    return tafseer_cache[key]
# ---------------------------------------------------------
# Load Quran Data
# ---------------------------------------------------------

def load_quran_data(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    verses = []
    references = []

    for surah in data:
        for ayah in surah["verses"]:
            verses.append(ayah["translation"])

            references.append({
                "surah_id": surah["id"],
                "ayah_id": ayah["id"],
                "surah_name": surah["transliteration"],
                "label": f"Surah {surah['id']} ({surah['transliteration']}), Ayah {ayah['id']}"
            })

    print(f"Loaded {len(verses)} verses.")
    return verses, references


verses, references = load_quran_data(QURAN_JSON_PATH)
tokenized_verses = [v.split(" ") for v in verses]
bm25 = BM25Okapi(tokenized_verses)
# ---------------------------------------------------------
# Create or Load FAISS Index
# ---------------------------------------------------------

def create_or_load_faiss_index():
    if os.path.exists(FAISS_INDEX_PATH):
        print("Loading existing FAISS index...")
        return faiss.read_index(FAISS_INDEX_PATH)

    print("Generating embeddings (first-time setup)...")

    embeddings = model.encode(verses, show_progress_bar=True)
    embeddings = np.array(embeddings).astype("float32")

    dimension = embeddings.shape[1]
    index = faiss.IndexFlatL2(dimension)
    index.add(embeddings)

    faiss.write_index(index, FAISS_INDEX_PATH)
    print("FAISS index created and saved.")

    return index


faiss_index = create_or_load_faiss_index()

print("\n--- Server Ready ---\n")

# =========================================================
# 2. API SETUP
# =========================================================

app = Flask(__name__)
CORS(app)

# ---------------------------------------------------------
# Helper: Search Relevant Verses
# ---------------------------------------------------------

def get_standalone_query(query, history):
    system_prompt = {
        "role": "system",
        "content": """
            You are a helpful assistant that extracts the core question from the user's message.

            Given the user's latest message and the conversation history, reformulate the user's message into a standalone question that does not rely on previous context.

            Rules:
            - Output ONLY the standalone question.
            - No explanations.
            - No references to previous messages.
        """,
    }

    messages = [system_prompt] + history.copy()
    messages.append({"role": "user", "content": query})

    response = client.chat.completions.create(
        model=GROQ_MODEL,
        messages=messages,
        temperature=0,
    )

    return response.choices[0].message.content.strip()

def search_relevant_verses(query, k=TOP_K, threshold=1.5):
    total_verses = len(verses)

    # -------------------------
    # 1️⃣ FAISS Semantic Search
    # -------------------------
    query_embedding = model.encode([query])
    query_embedding = np.array(query_embedding).astype("float32")

    distances, faiss_indices = faiss_index.search(query_embedding, k)

    # -------------------------
    # 2️⃣ BM25 Keyword Search
    # -------------------------
    tokenized_query = query.split(" ")
    bm25_scores = bm25.get_scores(tokenized_query)

    bm25_top_indices = np.argsort(bm25_scores)[::-1][:k]
    keyword_hits = list(bm25_top_indices)

    # -------------------------
    # 3️⃣ Merge (Remove Duplicates)
    # -------------------------
    combined_scores = {}

# --- Normalize BM25 ---
    max_bm25 = max(bm25_scores) if len(bm25_scores) > 0 else 1

    # --- Add FAISS similarity scores ---
    for distance, idx in zip(distances[0], faiss_indices[0]):
        if distance < threshold:
            semantic_score = 1 / (1 + distance)  # convert L2 distance to similarity
            combined_scores[idx] = semantic_score

    # --- Add normalized BM25 scores ---
    for idx in keyword_hits:
        normalized_bm25 = bm25_scores[idx] / max_bm25
        combined_scores[idx] = combined_scores.get(idx, 0) + normalized_bm25

    # --- Sort by final hybrid score ---
    sorted_indices = sorted(
        combined_scores.keys(),
        key=lambda x: combined_scores[x],
        reverse=True
    )

    # -------------------------
    # 4️⃣ Apply Window (Prev, Current, Next)
    # -------------------------
    final_results = []
    seen_window = set()

    for i in sorted_indices[:k]:

        window_indices = []

        if i - 1 >= 0 and references[i - 1]["surah_id"] == references[i]["surah_id"]:
            window_indices.append(i - 1)

        window_indices.append(i)

        if i + 1 < total_verses and references[i + 1]["surah_id"] == references[i]["surah_id"]:
            window_indices.append(i + 1)

        for idx in window_indices:
            if idx not in seen_window:
                seen_window.add(idx)

                ref = references[idx]
                final_results.append({
                    "surah_id": ref["surah_id"],
                    "ayah_id": ref["ayah_id"],
                    "label": ref["label"],
                    "verse": verses[idx]
                })

    return final_results if final_results else None

def classify_query(query, history):
    system_prompt = {
        "role": "system",
        "content": """
            You are a classification system.

            Classify the user's latest message into EXACTLY ONE category:

            QURANIC_SEARCH
            SMALL_TALK
            REFORMULATE

            Rules:
            - Output ONLY one category name.
            - No explanations.
            - No punctuation.
        """,
    }

    messages = [system_prompt] + history.copy()
    messages.append({"role": "user", "content": query})

    response = client.chat.completions.create(
        model=GROQ_MODEL,
        messages=messages,
        temperature=0,
    )

    return response.choices[0].message.content.strip()


# ---------------------------------------------------------
# Helper: Call Groq LLM
# ---------------------------------------------------------

def get_llm_response(messages):
    try:
        chat_completion = client.chat.completions.create(
            messages=messages,
            model=GROQ_MODEL,
            temperature=0.3,
        )
        return chat_completion.choices[0].message.content
    # except Exception as e:
    #     print(f"Groq API Error: {e}")
    #     return "I'm experiencing temporary issues. Please try again."
    except Exception as e:
        print("Groq API Error FULL:", repr(e))
        return f"DEBUG ERROR: {str(e)}"


# =========================================================
# 3. MAIN CHAT ENDPOINT
# =========================================================

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()

    if not data or "question" not in data or "history" not in data:
        return jsonify({"error": "Invalid request"}), 400

    query = data["question"]
    conversation_history = data["history"]

    # 1. Classify
    category = classify_query(query, conversation_history).strip().upper()
    
    # 2. Handle Small Talk
    if "SMALL_TALK" in category:
        messages = [{"role": "system", "content": "You are a polite Quran assistant."}] + conversation_history
        messages.append({"role": "user", "content": query})
        answer = get_llm_response(messages)
        return jsonify({"answer": answer, "sources": []})

    # 3. Handle Reformulation (Update query but continue to search)
    if "REFORMULATE" in category:
        query = get_standalone_query(query, conversation_history)
        # We don't return here; we proceed to search with the new query

    # 4. Search Logic (Now guaranteed to run for Search or Reformulated queries)
    retrieved_verses = []
    surah_match = None
    query_lower = query.lower()

    # Detect Surah name
    for ref in references:
        if ref["surah_name"].lower() in query_lower:
            surah_match = ref["surah_id"]
            break

    if surah_match:
        for i, ref in enumerate(references):
            if ref["surah_id"] == surah_match:
                retrieved_verses.append({
                    "surah_id": ref["surah_id"],
                    "ayah_id": ref["ayah_id"],
                    "label": ref["label"],
                    "verse": verses[i]
                })
        retrieved_verses = retrieved_verses[:8]
    else:
        retrieved_verses = search_relevant_verses(query)

    if not retrieved_verses:
        return jsonify({"answer": "I could not find relevant verses.", "sources": []})

    # 5. Tafseer Logic
    tafseer_context_parts = []
    for verse_data in retrieved_verses:
        tafseer_rag = get_tafseer_rag(verse_data["surah_id"], verse_data["ayah_id"])
        if tafseer_rag:
            relevant_chunks = search_tafseer(query, tafseer_rag["index"], tafseer_rag["chunks"], top_k=1)
            tafseer_context_parts.extend(relevant_chunks)

    # 6. Final LLM Answer
    verse_context = "\n\n".join([f"{v['label']}\n{v['verse']}" for v in retrieved_verses])
    tafseer_context = "\n\n".join(tafseer_context_parts) if tafseer_context_parts else "No tafseer available."

    system_message = {
        "role": "system",
        "content": "You are Quran AI. Summarize the following verses and tafseer in 2 paragraphs. Citation format: [Surah:Ayah]."
    }
    
    user_prompt = f"CONTEXT:\n{verse_context}\n\nTAFSEER:\n{tafseer_context}\n\nQuestion: {query}"
    
    messages = [system_message] + conversation_history[-4:] + [{"role": "user", "content": user_prompt}]
    
    final_answer = get_llm_response(messages)

    return jsonify({
        "answer": final_answer,
        "sources": [{"label": v["label"], "text": v["verse"]} for v in retrieved_verses]
    })
# =========================================================
# 4. RUN SERVER
# =========================================================

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)