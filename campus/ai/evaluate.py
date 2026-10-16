"""Run real model/RAG checks. Persists answers, evidence and latency for the demo."""
import argparse
import json
import statistics
import time
from pathlib import Path

import httpx

CASES = [
    ("solar", "太阳耀斑中的磁重联释放什么能量？请依据论文解释。", ["磁"]),
    ("finance", "根据2024年版指南，国内差旅报销需要准备哪些材料？", ["报销"]),
    ("finance", "校财帮应该从哪里进入和登录？", ["校财帮", "微信"]),
    ("library", "学生能借几本书，正常借期多久，能续借几次？", ["30", "60", "1"]),
    ("history", "科大什么时候在哪里建校，首任校长是谁？", ["1958", "北京", "郭沫若"]),
    ("history", "学校什么时候迁到合肥？", ["1970", "合肥"]),
    ("ai", "Qwen3 Embedding 论文提供哪些模型尺寸？", ["0.6", "4", "8"]),
]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8787")
    parser.add_argument("--output", default=str(Path(__file__).parent / "evaluation.json"))
    args = parser.parse_args()
    results = []
    with httpx.Client(timeout=120) as client:
        health = client.get(args.url + "/health").json()
        assert health["model_ready"] and health["retrieval"] == "qwen_embedding+bm25_rrf", health
        for role, question, expected in CASES:
            before = time.perf_counter()
            response = client.post(args.url + "/chat", json={"npc_id": role, "message": question})
            response.raise_for_status()
            result = response.json()
            passed = result["has_valid_citations"] and all(word in result["answer"] for word in expected)
            results.append({"npc_id": role, "question": question, "passed": passed,
                            "wall_seconds": round(time.perf_counter() - before, 2), **result})
            print(role, "PASS" if passed else "FAIL", results[-1]["wall_seconds"], flush=True)
    report = {"health": health, "passed": sum(r["passed"] for r in results), "total": len(results),
              "median_seconds": statistics.median(r["wall_seconds"] for r in results), "results": results}
    Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    raise SystemExit(0 if report["passed"] == len(results) else 1)
