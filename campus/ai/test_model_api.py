"""USTC transport contract, credentials, and all actual NPC entry points (offline)."""
import asyncio
import json
import os

import httpx
import pytest
from fastapi.testclient import TestClient

from model_api import ModelAPI, ModelAPIError, load_settings
from test_rag import api


def run_with_transport(config, send, operation):
    async def run():
        async with httpx.AsyncClient(transport=httpx.MockTransport(send)) as client:
            return await operation(config, client)
    return asyncio.run(run())


async def complete(config, client):
    return await config.complete(client, [{"role": "user", "content": "你好"}], temperature=0.3, max_tokens=2048)


def test_env_file_and_process_override_without_mutating_environment(tmp_path, monkeypatch):
    path = tmp_path / ".env"
    path.write_text("AI_PROVIDER=ustc\nUSTC_API_KEY=file-key\nUSTC_MODEL=file-model\n", encoding="utf-8-sig")
    monkeypatch.delenv("USTC_API_KEY", raising=False)
    monkeypatch.setenv("USTC_MODEL", "process-model")
    config = ModelAPI.from_settings(load_settings(path))
    assert config.api_key == "file-key" and config.model == "process-model"
    assert "USTC_API_KEY" not in os.environ
    assert "file-key" not in repr(config)


def test_missing_key_never_contacts_gateway():
    config = ModelAPI.from_settings({})
    def forbidden(request):
        pytest.fail("Missing-key requests must not leave the backend")
    result = run_with_transport(config, forbidden, lambda cfg, client: cfg.health(client))
    assert result["status"] == "configuration_required" and not result["model_ready"]
    with pytest.raises(ModelAPIError, match="USTC_API_KEY"):
        run_with_transport(config, forbidden, complete)


def test_backend_health_chat_and_guide_report_missing_key(monkeypatch):
    import importlib
    import app
    monkeypatch.setenv("AI_PROVIDER", "ustc")
    monkeypatch.setenv("USTC_API_KEY", "")
    monkeypatch.setenv("RAG_LEXICAL_ONLY", "1")
    module = importlib.reload(app)
    def forbidden(request):
        pytest.fail("Unconfigured backend must not contact USTC")
    with TestClient(module.app) as client:
        module.app.state.client = httpx.AsyncClient(transport=httpx.MockTransport(forbidden))
        status = client.get("/health").json()
        assert status["status"] == "configuration_required" and status["npcs"] == 15
        for route, body in [("/chat", {"npc_id": "library", "message": "学生借书期限"}),
                            ("/agent", {"message": "带我找图书馆员"})]:
            response = client.post(route, json=body)
            assert response.status_code == 503 and "USTC_API_KEY" in response.json()["detail"]


@pytest.mark.parametrize("provider", ["ustc", "qwen"])
def test_gateway_payload_and_bearer_header(provider):
    prefix = provider.upper()
    config = ModelAPI.from_settings({"AI_PROVIDER": provider, prefix + "_API_KEY": "test-key",
                                     prefix + "_MODEL": "exact-authorized-model"})
    def send(request):
        assert str(request.url) == config.base_url + "/chat/completions"
        assert request.headers["Authorization"] == "Bearer test-key"
        payload = json.loads(request.content)
        assert payload["model"] == "exact-authorized-model" and payload["stream"] is False
        assert ("chat_template_kwargs" in payload) == (provider == "qwen")
        return httpx.Response(200, json={"choices": [{"message": {"content": "<think>私有推理</think>你好"}}]})
    assert run_with_transport(config, send, complete) == "你好"


@pytest.mark.parametrize("status,fragment", [(401, "鉴权"), (403, "权限"), (429, "配额"), (404, "模型不存在"), (500, "返回异常")])
def test_upstream_errors_are_actionable_without_exposing_body(status, fragment):
    config = ModelAPI.from_settings({"USTC_API_KEY": "test-key"})
    def send(request):
        return httpx.Response(status, text="secret-echo-test-key")
    with pytest.raises(ModelAPIError, match=fragment) as error:
        run_with_transport(config, send, complete)
    assert "test-key" not in str(error.value)


@pytest.mark.parametrize("reply", [{}, {"choices": []}, {"choices": [{"message": {"content": None}}]},
                                   {"choices": [{"message": {"content": {"bad": "shape"}}}]},
                                   {"choices": [{"message": {"content": "<think>reasoning only</think>"}}]}])
def test_malformed_or_empty_response_is_a_controlled_error(reply):
    config = ModelAPI.from_settings({"USTC_API_KEY": "test-key"})
    with pytest.raises(ModelAPIError):
        run_with_transport(config, lambda request: httpx.Response(200, json=reply), complete)


@pytest.mark.parametrize("models,ready", [([{"id": "deepseek-v4-flash"}], True),
                                        ([{"id": "deepseek-v4-flash-ascend1"}], False), (None, False)])
def test_health_checks_exact_model_authorization(models, ready):
    config = ModelAPI.from_settings({"USTC_API_KEY": "test-key"})
    def send(request):
        assert request.method == "GET" and request.url.path == "/v1/models"
        assert request.headers["Authorization"] == "Bearer test-key"
        return httpx.Response(200, json={"data": models})
    result = run_with_transport(config, send, lambda cfg, client: cfg.health(client))
    assert result["model_ready"] is ready


def test_all_fifteen_npcs_and_action_guide_use_ustc(api):
    module, client = api
    called_prompts = []
    def send(request):
        assert str(request.url) == "https://api.llm.ustc.edu.cn/v1/chat/completions"
        assert request.headers["Authorization"] == "Bearer test-key-not-a-real-credential"
        payload = json.loads(request.content)
        assert payload["model"] == "deepseek-v4-flash" and "chat_template_kwargs" not in payload
        prompt = payload["messages"][0]["content"]
        called_prompts.append(prompt)
        content = json.dumps({"tool": "finish", "arguments": {"answer": "你好"}}) if "工具协议：" in prompt else "根据角色资料回答。[1]"
        return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})
    module.app.state.client = httpx.AsyncClient(transport=httpx.MockTransport(send))
    heroes = list(module.HEROES.values())
    assert len(heroes) == 15
    for hero in heroes:
        # Supply a corpus phrase too: this suite explicitly uses lexical retrieval,
        # so an English paper may not match its Chinese suggested question alone.
        phrase = next(p["text"][:100] for p in module.app.state.retriever.chunks if p["role"] == hero["id"])
        response = client.post("/chat", json={"npc_id": hero["id"], "message": hero["questions"][0] + "\n" + phrase,
                                             "history": [{"role": "user", "content": "你好"}]})
        assert response.status_code == 200, response.text
        data = response.json()
        assert data["provider"] == "ustc" and data["npc_id"] == hero["id"]
        assert hero["persona"] in called_prompts[-1]
        allowed = {p["chunk_id"] for p in module.app.state.retriever.chunks if p["role"] == hero["id"]}
        assert all(set(source["chunk_ids"]) <= allowed for source in data["sources"])
    guide = client.post("/agent", json={"message": "你好"})
    assert guide.status_code == 200 and guide.json()["provider"] == "ustc"
    assert len(called_prompts) == 16
