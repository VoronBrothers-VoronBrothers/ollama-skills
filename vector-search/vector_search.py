#!/usr/bin/env python3
"""Vector search for Ollama knowledge base using embedding models.

Usage:
    python3 vector_search.py index [--dir DIR] [--model MODEL] [--force]
    python3 vector_search.py search "query" [--k 5] [--min-score 0.75]
    python3 vector_search.py status

Storage: ~/.ollama/knowledge/.vector.db (SQLite)
Model:   qwen3-embedding:0.6b by default (configurable via --model or env VECTOR_MODEL)
"""

import argparse
import json
import math
import os
import re
import sqlite3
import struct
import sys
import time
from pathlib import Path

OLLAMA_API = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
KNOWLEDGE_DIR = Path(os.path.expanduser("~/.ollama/knowledge"))
DB_PATH = KNOWLEDGE_DIR / ".vector.db"
DEFAULT_MODEL = os.environ.get("VECTOR_MODEL", "qwen3-embedding:0.6b")
BATCH_SIZE = 32

# --- Chunking (mirrors Go internal/knowledge/chunker.go logic) ---

CHUNK_SIZE_WORDS = 500
OVERLAP_FRACTION = 0.10


def split_into_chunks(text: str, source: str) -> list[dict]:
    """Split text into ~500-word chunks with 10% overlap, markdown-aware."""
    # Try to respect markdown headers as boundaries
    lines = text.split("\n")
    paragraphs: list[str] = []
    current_heading = ""
    buf: list[str] = []

    for line in lines:
        header_match = re.match(r"^(#{1,6})\s+(.*)", line)
        if header_match:
            # Flush previous buffer
            if buf:
                paragraphs.append("\n".join(buf))
                buf = []
            current_heading = header_match.group(2).strip()
            buf.append(line)
        else:
            buf.append(line)
    if buf:
        paragraphs.append("\n".join(buf))

    # Merge small paragraphs into chunks of ~CHUNK_SIZE_WORDS words
    chunks: list[dict] = []
    current_words: list[str] = []
    current_text_parts: list[str] = []
    word_count = 0
    chunk_heading = ""

    for para in paragraphs:
        words = para.split()
        if not words and not para.strip():
            continue

        # If adding this paragraph would exceed limit, finalize current chunk
        if word_count + len(words) > CHUNK_SIZE_WORDS and current_words:
            text_chunk = "\n".join(current_text_parts)
            chunks.append({
                "text": text_chunk,
                "heading": chunk_heading,
                "source": source,
            })
            # Overlap: keep last 10% of words
            overlap_n = max(1, int(len(current_words) * OVERLAP_FRACTION))
            current_words = current_words[-overlap_n:]
            current_text_parts = [" ".join(current_words)]
            word_count = len(current_words)

        if not chunk_heading:
            # Try to extract heading from paragraph start
            h_match = re.match(r"^#{1,6}\s+(.*)", para)
            if h_match:
                chunk_heading = h_match.group(1).strip()

        current_words.extend(words)
        current_text_parts.append(para)
        word_count += len(words)

    # Final chunk
    if current_words:
        chunks.append({
            "text": "\n".join(current_text_parts),
            "heading": chunk_heading,
            "source": source,
        })

    return chunks


def collect_files(directory: Path) -> list[Path]:
    """Collect .txt and .md files (top-level + subdirs, skip hidden)."""
    files = []
    for p in sorted(directory.rglob("*")):
        if p.suffix.lower() in (".txt", ".md") and not any(
            part.startswith(".") for part in p.relative_to(directory).parts
        ):
            files.append(p)
    return files


# --- Database ---

def init_db(conn: sqlite3.Connection):
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS meta (
            key   TEXT PRIMARY KEY,
            value TEXT
        );
        CREATE TABLE IF NOT EXISTS chunks (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            source  TEXT NOT NULL,
            heading TEXT DEFAULT '',
            content TEXT NOT NULL,
            embedding BLOB NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_chunks_source ON chunks(source);
    """)
    conn.commit()


def get_meta(conn: sqlite3.Connection, key: str) -> str | None:
    row = conn.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
    return row[0] if row else None


def set_meta(conn: sqlite3.Connection, key: str, value: str):
    conn.execute(
        "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (key, value),
    )
    conn.commit()


def embedding_to_bytes(vec: list[float]) -> bytes:
    return struct.pack(f"{len(vec)}f", *vec)


def bytes_to_embedding(blob: bytes) -> list[float]:
    n = len(blob) // 4
    return list(struct.unpack(f"{n}f", blob))


# --- Ollama Embedding API ---

def embed_texts(texts: list[str], model: str, batch_size: int = BATCH_SIZE) -> list[list[float]]:
    """Embed a list of texts using Ollama /api/embed endpoint."""
    all_embeddings = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i : i + batch_size]
        payload = json.dumps({"model": model, "input": batch})
        import urllib.request

        req = urllib.request.Request(
            f"{OLLAMA_API}/api/embed",
            data=payload.encode(),
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.loads(resp.read())
        except Exception as e:
            print(f"  [embed] batch {i//batch_size + 1} failed: {e}", file=sys.stderr)
            raise

        # Response format: {"embeddings": [[...], [...], ...]}
        embs = data.get("embeddings", [])
        if len(embs) != len(batch):
            print(
                f"  [embed] warning: expected {len(batch)} embeddings, got {len(embs)}",
                file=sys.stderr,
            )
        all_embeddings.extend(embs)

    return all_embeddings


def embed_single(text: str, model: str) -> list[float]:
    """Embed a single text."""
    result = embed_texts([text], model, batch_size=1)
    return result[0] if result else []


# --- Cosine Similarity ---

def cosine_similarity(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    mag_a = math.sqrt(sum(x * x for x in a))
    mag_b = math.sqrt(sum(x * x for x in b))
    if mag_a == 0 or mag_b == 0:
        return 0.0
    return dot / (mag_a * mag_b)


# --- Commands ---

def cmd_index(args):
    directory = Path(args.dir).expanduser() if args.dir else KNOWLEDGE_DIR
    model = args.model or DEFAULT_MODEL

    if not directory.exists():
        print(f"Error: directory {directory} does not exist", file=sys.stderr)
        sys.exit(1)

    files = collect_files(directory)
    if not files:
        print(f"No .txt/.md files found in {directory}")
        return

    conn = sqlite3.connect(str(DB_PATH))
    init_db(conn)

    # Check for stale model
    existing_model = get_meta(conn, "model")
    if existing_model and existing_model != model and not args.force:
        print(
            f"Warning: index built with '{existing_model}', switching to '{model}'. "
            f"Use --force to rebuild.",
            file=sys.stderr,
        )
        conn.close()
        sys.exit(0)

    if args.force:
        conn.execute("DELETE FROM chunks")
        conn.commit()

    # Check which files are already indexed
    existing_sources = set(
        row[0] for row in conn.execute("SELECT DISTINCT source FROM chunks").fetchall()
    )

    total_chunks = 0
    new_files = []
    skipped = 0

    print(f"Indexing {len(files)} files with model '{model}'...")

    for fpath in files:
        rel_path = str(fpath)
        if rel_path in existing_sources and not args.force:
            skipped += 1
            continue

        try:
            text = fpath.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            print(f"  [skip] {fpath}: {e}", file=sys.stderr)
            continue

        if len(text.strip()) < 20:
            skipped += 1
            continue

        chunks = split_into_chunks(text, rel_path)
        if not chunks:
            skipped += 1
            continue

        # Embed all chunk texts
        texts = [c["text"] for c in chunks]
        try:
            embeddings = embed_texts(texts, model)
        except Exception as e:
            print(f"  [error] {fpath}: embedding failed: {e}", file=sys.stderr)
            continue

        # Insert into DB + commit per-file (so partial progress survives timeouts)
        now = time.time()
        for chunk, emb in zip(chunks, embeddings):
            conn.execute(
                "INSERT INTO chunks (source, heading, content, embedding, created_at) VALUES (?,?,?,?,?)",
                (chunk["source"], chunk["heading"], chunk["text"], embedding_to_bytes(emb), now),
            )
            total_chunks += 1
        conn.commit()

        print(f"  [ok] {fpath.name} → {len(chunks)} chunks")

    conn.commit()

    # Update metadata
    set_meta(conn, "model", model)
    set_meta(conn, "indexed_at", str(time.time()))
    file_count = len(set(r[0] for r in conn.execute("SELECT DISTINCT source FROM chunks").fetchall()))
    chunk_count = conn.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]

    print(f"\nDone: {file_count} files, {chunk_count} total chunks ({total_chunks} new, {skipped} skipped)")
    conn.close()


def cmd_search(args):
    query = args.query
    model = args.model or DEFAULT_MODEL
    k = args.k
    min_score = args.min_score

    if not DB_PATH.exists():
        print("No vector index found. Run 'index' first.", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(str(DB_PATH))
    init_db(conn)

    # Verify model matches
    db_model = get_meta(conn, "model")
    if db_model and db_model != model:
        print(f"Warning: index uses '{db_model}', query using '{model}'. Results may be poor.", file=sys.stderr)

    # Embed the query
    try:
        q_emb = embed_single(query, model)
    except Exception as e:
        print(f"Error embedding query: {e}", file=sys.stderr)
        conn.close()
        sys.exit(1)

    if not q_emb:
        print("Error: empty embedding returned for query", file=sys.stderr)
        conn.close()
        sys.exit(1)

    # Search all chunks by cosine similarity
    rows = conn.execute("SELECT id, source, heading, content, embedding FROM chunks").fetchall()
    if not rows:
        print("Index is empty. Run 'index' first.")
        conn.close()
        return

    scored = []
    for row in rows:
        chunk_id, source, heading, content, emb_blob = row
        doc_emb = bytes_to_embedding(emb_blob)
        sim = cosine_similarity(q_emb, doc_emb)
        if sim >= min_score:
            scored.append((sim, chunk_id, source, heading, content))

    # Sort by similarity descending, take top-k
    scored.sort(key=lambda x: x[0], reverse=True)
    results = scored[:k]

    # Output as JSON for programmatic use
    output = {
        "query": query,
        "model": model,
        "total_chunks": len(rows),
        "results": [
            {
                "score": round(score, 4),
                "source": source,
                "heading": heading,
                "content": content[:2000],  # cap at ~2k chars for LLM context
            }
            for score, _, source, heading, content in results
        ],
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))
    conn.close()


def cmd_status(args):
    if not DB_PATH.exists():
        print("No vector index found.")
        return

    conn = sqlite3.connect(str(DB_PATH))
    init_db(conn)

    model = get_meta(conn, "model") or "unknown"
    indexed_at = get_meta(conn, "indexed_at")
    chunk_count = conn.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    file_count = len(set(r[0] for r in conn.execute("SELECT DISTINCT source FROM chunks").fetchall()))

    print(f"Vector index: {DB_PATH}")
    print(f"  Model:     {model}")
    if indexed_at:
        print(f"  Indexed:   {time.strftime('%Y-%m-%d %H:%M', time.localtime(float(indexed_at)))}")
    print(f"  Files:     {file_count}")
    print(f"  Chunks:    {chunk_count}")
    conn.close()


def main():
    parser = argparse.ArgumentParser(description="Vector search for Ollama knowledge base")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # index
    p_idx = subparsers.add_parser("index", help="Index files with embeddings")
    p_idx.add_argument("--dir", default=None, help="Directory to index (default: ~/.ollama/knowledge)")
    p_idx.add_argument("--model", default=None, help=f"Embedding model (default: {DEFAULT_MODEL})")
    p_idx.add_argument("--force", action="store_true", help="Rebuild entire index")

    # search
    p_search = subparsers.add_parser("search", help="Search by semantic similarity")
    p_search.add_argument("query", help="Search query text")
    p_search.add_argument("--model", default=None, help=f"Embedding model (default: {DEFAULT_MODEL})")
    p_search.add_argument("--k", type=int, default=5, help="Number of results (default: 5)")
    p_search.add_argument("--min-score", type=float, default=0.45, help="Minimum cosine similarity (default: 0.45)")

    # status
    subparsers.add_parser("status", help="Show index status")

    args = parser.parse_args()

    if args.command == "index":
        cmd_index(args)
    elif args.command == "search":
        cmd_search(args)
    elif args.command == "status":
        cmd_status(args)


if __name__ == "__main__":
    main()
