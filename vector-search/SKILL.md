# Vector Search (Embedding-based RAG)

Semantic search over `~/.ollama/knowledge/` using an embedding model.
Use when keyword/BM25 search (`knowledge_search` tool) is insufficient —
especially for: synonym queries, cross-language search, conceptual matching.

## When to use this skill

- User asks a question where exact keywords won't match (paraphrases, concepts)
- Cross-language: Russian query → English docs or vice versa
- "Find me the section about X" when X is described differently in the source
- After `knowledge_search` returned poor/empty results and you need a second pass

## When NOT to use

- Simple keyword lookup (use built-in `knowledge_search` tool — faster, no model needed)
- Code search / regex patterns (use `search_files`)
- The knowledge base hasn't been indexed yet AND user doesn't want to wait for indexing

## How to run

All commands from this skill directory:

```bash
# Check if index exists and is up-to-date
python3 vector_search.py status

# Index the knowledge base (first time or after adding files)
python3 vector_search.py index

# Force full reindex (after model change or corruption)
python3 vector_search.py index --force

# Search (returns JSON with top-k results, scores, sources)
python3 vector_search.py search "your question here" --k 5

# Adjust sensitivity: lower min-score = more results but noisier
python3 vector_search.py search "query" --min-score 0.70

# Use a different model (e.g., higher quality):
python3 vector_search.py index --model qwen3-embedding:4b
```

## Output format (search)

JSON with `results` array. Each result has:
- `score`: cosine similarity (0–1, higher = more relevant)
- `source`: file path
- `heading`: section heading if detected
- `content`: chunk text (capped at 2000 chars)

## Combining with BM25

For best results on complex queries:
1. Run `knowledge_search` tool first (fast, catches exact keywords)
2. If results are empty or unsatisfactory → run this skill's search
3. Merge both sets of results for the final answer

## Indexing notes

- First index can take time (embedding each chunk via Ollama API)
- Subsequent runs only index NEW files (incremental by default)
- `--force` rebuilds everything
- Default model: `qwen3-embedding:0.6b` (~470MB, fast on CPU)
- For higher quality: `qwen3-embedding:4b` (slower but better multilingual)

## Limitations

- Requires Ollama running with the embedding model available
- First search after cold start may be slow (model load ~1-2s)
- Not a replacement for structured code search
- Chunks are ~500 words — very long documents get many chunks
