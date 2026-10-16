"""Exercise each actual NPC's first suggested question against the deployed model."""
import argparse
import json
import statistics
import time
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parent

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8787")
    args = parser.parse_args()
    heroes = json.loads((ROOT.parent / "godot/data/hero_npcs.json").read_text(encoding="utf-8"))
    results = []
    with httpx.Client(timeout=120) as client:
        health = client.get(args.url + "/health").json()
        assert health["model_ready"] and health["npcs"] == 15, health
        for hero in heroes:
            question = hero["questions"][0]
            started = time.perf_counter()
            response = client.post(args.url + "/chat", json={"npc_id": hero["id"], "message": question})
            response.raise_for_status()
            data = response.json()
            result = {"npc_id": hero["id"], "question": question, "wall_seconds": round(time.perf_counter() - started, 2), **data}
            results.append(result)
            print(hero["id"], "CITATIONS_OK" if data["has_valid_citations"] else "NO_CITATIONS", result["wall_seconds"], flush=True)
    report = {"health": health, "valid_citations": sum(r["has_valid_citations"] for r in results), "total": len(results),
              "median_seconds": statistics.median(r["wall_seconds"] for r in results), "results": results}
    (ROOT / "cast_evaluation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
