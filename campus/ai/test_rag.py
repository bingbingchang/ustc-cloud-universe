import importlib
import json
import os
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from retrieval import Retriever


def test_sources_and_role_isolation():
    r = Retriever(lexical_only=True)
    heroes = json.loads((Path(__file__).parent.parent / "godot/data/hero_npcs.json").read_text(encoding="utf-8"))
    assert {c["role"] for c in r.chunks} == {h["id"] for h in heroes}
    assert len(heroes) == 15
    for role, question in [("finance", "国内差旅报销材料"), ("library", "借书期限续借"),
                           ("history", "1958年建校"), ("solar", "magnetic reconnection"), ("ai", "embedding reranking")]:
        passages = r.search(role, question)
        assert passages and all(p["role"] == role and p["url"].startswith("https://") for p in passages)
    library = " ".join(c["text"] for c in r.chunks if c["role"] == "library")
    assert "30册" in library and "60天" in library and "学生" in library
    assert not any("\ufffd" in c["text"] for c in r.chunks)


@pytest.fixture
def api(monkeypatch):
    monkeypatch.setenv("RAG_LEXICAL_ONLY", "1")
    import app
    importlib.reload(app)
    with TestClient(app.app) as client:
        yield app, client


def test_generation_receives_scoped_evidence_and_keeps_citations(api):
    module, client = api
    captured = {}

    async def fake_send(request):
        captured.update(json.loads(request.content))
        return httpx.Response(200, json={"choices": [{"message": {"content": "学生可借30册，正常借期60天。[1]"}}]})

    module.app.state.client = httpx.AsyncClient(transport=httpx.MockTransport(fake_send))
    response = client.post("/chat", json={"npc_id": "library", "message": "学生能借多久？"})
    assert response.status_code == 200
    data = response.json()
    assert data["has_valid_citations"] and data["sources"][0]["citation"] == 1
    assert all("lib.ustc.edu.cn" in s["url"] for s in data["sources"])
    assert "检索资料" in captured["messages"][0]["content"]
    assert captured["chat_template_kwargs"] == {"enable_thinking": False}


def test_model_failure_is_reported_and_unknown_role_rejected(api):
    module, client = api
    async def failure(request):
        return httpx.Response(503, text="model offline")
    module.app.state.client = httpx.AsyncClient(transport=httpx.MockTransport(failure))
    assert client.post("/chat", json={"npc_id": "finance", "message": "报销材料"}).status_code == 503
    assert client.post("/chat", json={"npc_id": "missing", "message": "你好"}).status_code == 404
    assert client.post("/chat", json={"npc_id": "finance", "message": "x" * 1201}).status_code == 422


def test_follow_up_uses_recent_question(api):
    _, client = api
    response = client.post("/retrieve", json={"npc_id": "finance", "message": "需要哪些材料呢？",
        "history": [{"role": "user", "content": "我准备办理国内差旅报销"}]})
    assert response.status_code == 200
    assert any("差旅" in p["text"] for p in response.json()["passages"])


def test_document_citations_keep_all_retrieved_pages(api):
    module, _ = api
    source = module.app.state.retriever.search("finance", "国内差旅报销材料", limit=4)
    docs = module.evidence_documents(source)
    assert sum(len(d["chunk_ids"]) for d in docs) == len(source)
    for passage in source:
        document = next(d for d in docs if passage["chunk_id"] in d["chunk_ids"])
        assert passage["location"] in document["location"] and passage["text"] in document["text"]
