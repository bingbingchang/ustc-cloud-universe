"""Role-scoped vector retrieval + lexical rank fusion for a small document corpus."""
import json
import re
from collections import Counter
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent
EMBEDDING_MODEL = "Qwen/Qwen3-Embedding-0.6B"
INSTRUCTION = "Given a player question, retrieve passages that answer the question from this character's documents."


def query_text(text):
    return f"Instruct: {INSTRUCTION}\nQuery: {text}"


def tokens(text):
    text = text.lower()
    latin = re.findall(r"[a-z0-9]+", text)
    chinese = re.findall(r"[\u4e00-\u9fff]+", text)
    return latin + [s[i:i + 2] for s in chinese for i in range(len(s) - 1)]


class Retriever:
    def __init__(self, directory=None, lexical_only=False):
        directory = Path(directory or ROOT / "knowledge")
        self.chunks = json.loads((directory / "chunks.json").read_text(encoding="utf-8"))
        self.lexical_only = lexical_only
        self.vectors = None
        if not lexical_only:
            index = np.load(directory / "vectors.npz", allow_pickle=False)
            if index["chunk_ids"].tolist() != [c["chunk_id"] for c in self.chunks]:
                raise RuntimeError("Knowledge changed: run build_index.py again")
            if str(index["model"].item()) != EMBEDDING_MODEL:
                raise RuntimeError("Embedding model mismatch")
            self.vectors = index["vectors"]
        self.docs = [Counter(tokens(c["text"] + " " + c["title"] + " " + c.get("topics", ""))) for c in self.chunks]

    def search(self, role, question, query_vector=None, limit=4):
        ids = [i for i, c in enumerate(self.chunks) if c["role"] == role]
        if not ids:
            return []
        query = Counter(tokens(question))
        # BM25 statistics are computed within the role's namespace.
        lengths = {i: sum(self.docs[i].values()) for i in ids}
        average = max(1, sum(lengths.values()) / len(ids))
        lexical = {}
        for i in ids:
            score = 0.0
            for word in query:
                df = sum(word in self.docs[j] for j in ids)
                idf = np.log(1 + (len(ids) - df + .5) / (df + .5))
                tf = self.docs[i][word]
                score += idf * tf * 2.2 / (tf + 1.2 * (.25 + .75 * lengths[i] / average))
            lexical[i] = float(score)
        ranks = [sorted((i for i in ids if lexical[i] > 0), key=lambda i: lexical[i], reverse=True)]
        semantic = {}
        if not self.lexical_only:
            if query_vector is None:
                raise ValueError("Vector retrieval requires a query embedding")
            q = np.asarray(query_vector, dtype=np.float32)
            q /= max(float(np.linalg.norm(q)), 1e-12)
            semantic = {i: float(self.vectors[i] @ q) for i in ids}
            ranks.append(sorted(ids, key=lambda i: semantic[i], reverse=True))
        fusion = {}
        for ranking in ranks:
            for rank, i in enumerate(ranking):
                fusion[i] = fusion.get(i, 0) + 1 / (60 + rank + 1)
        selected = sorted(fusion, key=fusion.get, reverse=True)[:limit]
        return [{**self.chunks[i], "score": round(fusion[i], 6),
                 "vector_score": round(semantic[i], 4) if i in semantic else None} for i in selected]
