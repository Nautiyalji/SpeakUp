"""
RAG Service — Job Description embedding and retrieval.
Uses ChromaDB (local persistent) + sentence-transformers (all-MiniLM-L6-v2).

Flow:
  1. User uploads JD text/PDF  →  chunk  →  embed  →  store in ChromaDB
  2. Panelist generates question  →  retrieve top-k chunks  →  inject into prompt
"""
import asyncio
import uuid
import os
from typing import Optional

# Lazy imports — heavy libs loaded only when needed
_embedder = None
_chroma_client = None
CHROMA_DB_PATH = os.path.join(os.path.dirname(__file__), "..", "..", "chroma_db")
EMBED_MODEL = "all-MiniLM-L6-v2"


def _get_embedder():
    global _embedder
    if _embedder is None:
        from sentence_transformers import SentenceTransformer
        print("[RAG] Loading sentence-transformer model...")
        _embedder = SentenceTransformer(EMBED_MODEL)
        print("[RAG] Embedder ready.")
    return _embedder


def _get_chroma():
    global _chroma_client
    if _chroma_client is None:
        import chromadb
        _chroma_client = chromadb.PersistentClient(path=CHROMA_DB_PATH)
        print(f"[RAG] ChromaDB initialized at {CHROMA_DB_PATH}")
    return _chroma_client


def _chunk_text(text: str, chunk_size: int = 400, overlap: int = 80) -> list[str]:
    """Split text into overlapping word-level chunks."""
    words = text.split()
    chunks = []
    start = 0
    while start < len(words):
        end = min(start + chunk_size, len(words))
        chunks.append(" ".join(words[start:end]))
        start += chunk_size - overlap
    return [c for c in chunks if len(c.strip()) > 20]


async def index_jd(jd_text: str, interview_id: str) -> int:
    """
    Chunk and embed a job description, store in ChromaDB.
    Returns number of chunks stored.
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _index_jd_sync, jd_text, interview_id)


def _index_jd_sync(jd_text: str, interview_id: str) -> int:
    client = _get_chroma()
    embedder = _get_embedder()

    # Delete old collection if re-indexing same interview
    try:
        client.delete_collection(name=interview_id)
    except Exception:
        pass

    collection = client.create_collection(
        name=interview_id,
        metadata={"hnsw:space": "cosine"},
    )

    chunks = _chunk_text(jd_text)
    if not chunks:
        return 0

    embeddings = embedder.encode(chunks).tolist()
    ids = [f"{interview_id}_{i}" for i in range(len(chunks))]

    collection.add(documents=chunks, embeddings=embeddings, ids=ids)
    print(f"[RAG] Indexed {len(chunks)} chunks for interview {interview_id}")
    return len(chunks)


async def retrieve_context(query: str, interview_id: str, top_k: int = 3) -> str:
    """
    Retrieve the most relevant JD chunks for a given query.
    Returns concatenated text of top-k chunks.
    """
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _retrieve_sync, query, interview_id, top_k)


def _retrieve_sync(query: str, interview_id: str, top_k: int) -> str:
    try:
        client = _get_chroma()
        embedder = _get_embedder()

        collection = client.get_collection(name=interview_id)
        query_embedding = embedder.encode([query]).tolist()

        results = collection.query(
            query_embeddings=query_embedding,
            n_results=min(top_k, collection.count()),
        )
        docs = results.get("documents", [[]])[0]
        return "\n\n".join(docs)
    except Exception as e:
        print(f"[RAG] Retrieval error (returning empty): {e}")
        return ""


async def parse_pdf_to_text(pdf_bytes: bytes) -> str:
    """Extract text from a PDF byte string."""
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _parse_pdf_sync, pdf_bytes)


def _parse_pdf_sync(pdf_bytes: bytes) -> str:
    import io
    from pypdf import PdfReader
    reader = PdfReader(io.BytesIO(pdf_bytes))
    pages = [page.extract_text() or "" for page in reader.pages]
    return "\n".join(pages)
