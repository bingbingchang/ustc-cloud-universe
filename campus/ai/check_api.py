"""Check local configuration; contact USTC only with the explicit --online flag."""
import argparse
import asyncio
import json
from pathlib import Path

import httpx

from model_api import ModelAPI, ModelAPIError, load_settings


async def check(online=False):
    root = Path(__file__).resolve().parent
    config = ModelAPI.from_settings(load_settings(root / ".env"))
    heroes = json.loads((root.parent / "godot/data/hero_npcs.json").read_text(encoding="utf-8"))
    report = {"provider": config.provider, "base_url": config.base_url, "model": config.model,
              "api_key_configured": bool(config.api_key), "npcs": len(heroes), "online_test": online}
    if not online:
        report["status"] = "configuration_required" if config.configuration_error else "configured_not_connected"
        report["detail"] = config.configuration_error or "本地配置已读取，尚未验证网络、模型权限或真实回答。"
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    async with httpx.AsyncClient(timeout=90) as client:
        report.update(await config.health(client))
        if report["model_ready"]:
            try:
                answer = await config.complete(client, [{"role": "user", "content": "请只回复：连接成功"}],
                                               temperature=0.1, max_tokens=2048)
                report["generation_ready"] = bool(answer)
                # Do not print upstream content: this check only needs a success flag.
            except ModelAPIError as exc:
                report.update(status="generation_unavailable", generation_ready=False, detail=str(exc))
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0 if report.get("generation_ready") else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--online", action="store_true", help="Verify model authorization and one real generation (uses quota).")
    args = parser.parse_args()
    raise SystemExit(asyncio.run(check(args.online)))
