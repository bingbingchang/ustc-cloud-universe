"""Per-player credentials stay request-local across health, NPC and guide routes."""
import json

import httpx
import pytest

from model_api import ModelAPI
from test_rag import api


def test_override_keeps_host_and_shared_budget():
    host = ModelAPI.from_settings({"USTC_API_KEY": "host-fake"})
    player = host.with_session_key("player-fake")
    assert player.api_key == "player-fake" and host.api_key == "host-fake"
    assert player.budget is host.budget
    assert host.with_session_key(None) is host
    assert host.with_session_key("") is host
    assert "player-fake" not in repr(player)


@pytest.mark.parametrize("key", ["bad key", "bad\nkey", "密钥", "x" * 513])
def test_invalid_key_is_not_echoed(key):
    with pytest.raises(ValueError) as error:
        ModelAPI.from_settings({}).with_session_key(key)
    assert key not in str(error.value)


def test_two_players_and_host_are_isolated_on_all_routes(api):
    module, client = api
    host_key = module.MODEL_API.api_key
    seen = []

    def send(request):
        seen.append(request.headers["Authorization"])
        if request.url.path.endswith("/models"):
            return httpx.Response(200, json={"data": [{"id": module.MODEL_API.model}]})
        payload = json.loads(request.content)
        assert all(key not in request.content.decode() for key in ["player-a-fake", "player-b-fake", host_key])
        content = json.dumps({"tool": "finish", "arguments": {"answer": "你好"}}) if "工具协议：" in payload["messages"][0]["content"] else "学生借期60天。[1]"
        return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})

    module.app.state.client = httpx.AsyncClient(transport=httpx.MockTransport(send))
    for key in ["player-a-fake", "player-b-fake", None, "player-a-fake", None]:
        headers = {"X-Campus-API-Key": key} if key else {}
        for route, body in [("/health", None), ("/chat", {"npc_id": "library", "message": "学生借书期限"}),
                            ("/agent", {"message": "你好"})]:
            response = client.get(route, headers=headers) if body is None else client.post(route, headers=headers, json=body)
            assert response.status_code == 200, response.text
            assert seen[-1] == "Bearer " + (key or host_key)
            assert all(secret not in response.text for secret in ["player-a-fake", "player-b-fake", host_key])
            assert module.MODEL_API.api_key == host_key
    before = len(seen)
    assert client.get("/health", headers={"X-Campus-API-Key": "invalid key"}).status_code == 400
    assert len(seen) == before


def test_relay_forwards_only_explicit_session_key(monkeypatch):
    import importlib
    from fastapi.testclient import TestClient
    monkeypatch.setenv("CAMPUS_RELAY_TOKEN", "relay-fake-" + "x" * 40)
    import web_relay
    relay = importlib.reload(web_relay)
    seen = []
    with TestClient(relay.app) as client:
        def send(request):
            seen.append(request.headers.get("X-Campus-API-Key"))
            assert "Authorization" not in request.headers
            return httpx.Response(200, json={"ok": True})
        relay.app.state.client = httpx.AsyncClient(transport=httpx.MockTransport(send))
        headers = {"Authorization": "Bearer " + relay.TOKEN}
        for key in ["player-a-fake", None, "player-b-fake"]:
            response = client.get("/health", headers={**headers, **({"X-Campus-API-Key": key} if key else {})})
            assert response.status_code == 200 and seen[-1] == key
        assert client.get("/health", headers={**headers, "X-Campus-API-Key": "bad key"}).status_code == 400
        assert len(seen) == 3
