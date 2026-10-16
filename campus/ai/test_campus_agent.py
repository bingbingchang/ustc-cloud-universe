"""Exercise model tool decisions and the real game acknowledgement boundary."""
import importlib
import json

import httpx
import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def api(monkeypatch):
    monkeypatch.setenv("RAG_LEXICAL_ONLY", "1")
    import app
    importlib.reload(app)
    with TestClient(app.app) as client:
        yield app, client


def mock_model(module, decisions):
    captured = []

    async def send(request):
        captured.append(json.loads(request.content))
        decision = decisions.pop(0)
        return httpx.Response(200, json={"choices": [{"message": {"content": json.dumps(decision, ensure_ascii=False)}}]})

    module.app.state.client = httpx.AsyncClient(transport=httpx.MockTransport(send))
    return captured


def test_goal_uses_role_search_rag_and_two_acknowledged_game_tools(api):
    module, client = api
    captured = mock_model(module, [
        {"tool": "search_npcs", "arguments": {"query": "图书馆 借书"}},
        {"tool": "query_npc_knowledge", "arguments": {"npc_id": "library", "question": "学生借书册数和借期"}},
        {"tool": "request_game_action", "arguments": {"type": "navigate_to_npc", "npc_id": "library"}},
        {"tool": "request_game_action", "arguments": {"type": "open_npc_dialogue", "npc_id": "library"}},
        {"tool": "finish", "arguments": {"answer": "学生可借30册、60天。[1] 已快速前往沈书宁身边并打开对话。"}},
    ])
    goal = "帮我查学生借书规则，带我找能解答的老师并打开对话"
    first = client.post("/agent", json={"message": goal}).json()
    assert first["status"] == "awaiting_game"
    assert [row["tool"] for row in first["tool_trace"]] == ["search_npcs", "query_npc_knowledge", "request_game_action"]
    assert first["actions"][0]["npc_id"] == "library"
    assert first["sources"] and all("lib.ustc.edu.cn" in source["url"] for source in first["sources"])
    assert "叶新程" in captured[0]["messages"][0]["content"]
    assert any("30册" in message["content"] for message in captured[2]["messages"])

    # Retrying while the game has not reported its result must not ask the model to claim success.
    waiting = client.post("/agent", json={"message": goal, "state": first["state"]}).json()
    assert waiting["actions"] == first["actions"] and len(captured) == 3

    second = client.post("/agent", json={"message": goal, "state": first["state"], "observations": [
        {"action_id": first["actions"][0]["id"], "status": "success", "detail": {"npc_id": "library", "distance_to_npc": 2.8}}
    ]}).json()
    assert second["actions"][0]["type"] == "open_npc_dialogue"
    final = client.post("/agent", json={"message": goal, "state": second["state"], "observations": [
        {"action_id": second["actions"][0]["id"], "status": "success", "detail": {"dialogue_open": True}}
    ]}).json()
    assert final["status"] == "completed" and final["actions"] == []
    assert final["sources"][0]["cited"]
    assert len([row for row in final["tool_trace"] if row["tool"] == "game_observation"]) == 2
    assert "dialogue_open" in captured[-1]["messages"][-1]["content"]


def test_failed_game_action_is_seen_by_model_and_reported(api):
    module, client = api
    captured = mock_model(module, [
        {"tool": "request_game_action", "arguments": {"type": "navigate_to_npc", "npc_id": "library"}},
        {"tool": "finish", "arguments": {"answer": "游戏未能完成快速前往：目标角色不在当前场景。"}},
    ])
    first = client.post("/agent", json={"message": "带我找图书馆员"}).json()
    final = client.post("/agent", json={"message": "带我找图书馆员", "state": first["state"], "observations": [
        {"action_id": first["actions"][0]["id"], "status": "failed", "detail": "目标角色不在当前场景"}
    ]}).json()
    assert "failed" in captured[-1]["messages"][-1]["content"]
    assert "未能" in final["answer"] and final["status"] == "completed"


def test_invalid_model_decision_is_visible_error(api):
    module, client = api
    mock_model(module, [{"answer": "pretend this is a tool call"}])
    response = client.post("/agent", json={"message": "帮我查借书规则"})
    assert response.status_code == 503
    assert "解析失败" in response.json()["detail"]
