import os
import json
from pathlib import Path

import numpy as np
import torch
from sentence_transformers import SentenceTransformer

from retrieval import EMBEDDING_MODEL, ROOT


if __name__ == "__main__":
    torch.set_num_threads(int(os.getenv("TORCH_CPU_THREADS", "4")))
    chunks = json.loads((ROOT / "knowledge/chunks.json").read_text(encoding="utf-8"))
    device = os.getenv("EMBEDDING_DEVICE", "cpu")
    model = SentenceTransformer(os.getenv("EMBEDDING_MODEL_PATH", EMBEDDING_MODEL), device=device,
                                model_kwargs={"torch_dtype": torch.bfloat16} if device != "cpu" else {})
    model.max_seq_length = 1024
    vectors = model.encode([c["text"] for c in chunks], batch_size=8,
                           normalize_embeddings=True, show_progress_bar=True)
    np.savez_compressed(ROOT / "knowledge/vectors.npz", vectors=vectors,
                        chunk_ids=np.asarray([c["chunk_id"] for c in chunks]), model=EMBEDDING_MODEL)
    print("INDEX_READY", vectors.shape)
