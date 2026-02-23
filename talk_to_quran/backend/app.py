import json
import os
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer
from groq import Groq
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

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
TOP_K = 5  # Number of verses to retrieve

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

# ---------------------------------------------------------
# Load Quran Data
# ---------------------------------------------------------

def load_quran_data(file_path):
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError(f"{file_path} not found.")

    verses = []
    references = []

    for surah in data:
        for ayah in surah["verses"]:
            verses.append(ayah["translation"])
            references.append(
                f"Surah {surah['id']} ({surah['transliteration']}), Ayah {ayah['id']}"
            )

    print(f"Loaded {len(verses)} verses.")
    return verses, references


verses, references = load_quran_data(QURAN_JSON_PATH)

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

def search_relevant_verses(query, k=TOP_K):
    query_embedding = model.encode([query])
    query_embedding = np.array(query_embedding).astype("float32")

    distances, indices = faiss_index.search(query_embedding, k)

    retrieved_context = []
    for i in indices[0]:
        retrieved_context.append(
            f"Reference: {references[i]}\nVerse: {verses[i]}"
        )

    return "\n\n".join(retrieved_context)


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
    except Exception as e:
        print(f"Groq API Error: {e}")
        return "I'm experiencing temporary issues. Please try again."


# =========================================================
# 3. MAIN CHAT ENDPOINT
# =========================================================

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()

    # ---- Validate request body ----
    if not data or "question" not in data or "history" not in data:
        return jsonify(
            {"error": "Invalid request body. 'question' and 'history' required."}
        ), 400

    query = data["question"]
    conversation_history = data["history"]

    # ---- Basic safety checks ----
    if not isinstance(query, str) or len(query.strip()) == 0:
        return jsonify({"error": "Question must be a non-empty string."}), 400

    if len(query) > 1000:
        return jsonify({"error": "Question too long."}), 400

    # ---- Retrieve context from FAISS ----
    retrieved_context = search_relevant_verses(query)

    # ---- System Prompt (Anti-Hallucination Guard) ----
    system_message = {
        "role": "system",
        "content": (
            "You are a knowledgeable and respectful Quran assistant. "
            "Answer ONLY using the provided Quranic context. "
            "If the answer is not found in the context, clearly say so. "
            "Do not fabricate verses or interpretations."
        ),
    }

    # ---- Augment user query with context ----
    user_message_content = (
        f"CONTEXT:\n"
        f"---------------------\n"
        f"{retrieved_context}\n"
        f"---------------------\n\n"
        f"Based on the context above, answer the following question:\n{query}"
    )

    # ---- Build messages safely (no mutation) ----
    messages = [system_message] + conversation_history.copy()
    messages.append({"role": "user", "content": user_message_content})

    # ---- Get LLM response ----
    final_answer = get_llm_response(messages)

    return jsonify({"answer": final_answer})


# =========================================================
# 4. RUN SERVER
# =========================================================

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)