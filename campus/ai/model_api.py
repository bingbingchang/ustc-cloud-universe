"""Server-side model gateway shared by every NPC and the campus agent."""
import os
import re
from dataclasses import dataclass, field, replace

import httpx
from dotenv import dotenv_values
from call_budget import CallBudget, ModelRateLimitError


def load_settings(path):
    values = {k: v for k, v in dotenv_values(path, encoding="utf-8-sig").items() if v is not None}
    return {**values, **os.environ}


class ModelAPIError(Exception):
    """A safe, actionable error for the game, without upstream bodies or credentials."""


@dataclass(frozen=True)
class ModelAPI:
    provider: str
    base_url: str
    model: str
    api_key: str = field(default="", repr=False)
    budget: CallBudget | None = field(default=None, repr=False, compare=False)

    @classmethod
    def from_settings(cls, settings):
        provider = settings.get("AI_PROVIDER", "ustc").strip().lower()
        if provider not in ("ustc", "qwen"):
            raise ValueError("AI_PROVIDER must be ustc or qwen")
        if provider == "ustc":
            prefix, url, model = "USTC", "https://api.llm.ustc.edu.cn/v1", "deepseek-v4-flash"
        else:
            prefix, url, model = "QWEN", "http://127.0.0.1:8000/v1", "Qwen/Qwen3-8B"
        return cls(provider, (settings.get(prefix + "_BASE_URL") or url).strip().rstrip("/"),
                   (settings.get(prefix + "_MODEL") or model).strip(),
                   (settings.get(prefix + "_API_KEY") or "").strip(),
                   CallBudget(int(settings.get("MODEL_MAX_CONCURRENCY", "2")), int(settings.get("MODEL_CALLS_PER_MINUTE", "10"))))

    @property
    def headers(self):
        return {"Authorization": "Bearer " + self.api_key} if self.api_key else {}

    def with_session_key(self, key):
        """An ephemeral credential override; keep the host config and shared budget intact."""
        if key is None or key == "":
            return self
        if self.provider != "ustc":
            raise ValueError("当前后台未启用科大接口，请主机切换后再填写个人 Key。")
        if not isinstance(key, str) or not re.fullmatch(r"[\x21-\x7e]{1,512}", key):
            raise ValueError("API Key 格式无效，请粘贴完整 Key，不要包含空格或换行。")
        return replace(self, api_key=key)

    @property
    def configuration_error(self):
        if self.provider == "ustc" and not self.api_key:
            return "尚未配置科大 API Key，请在 campus/ai/.env 填写 USTC_API_KEY 后重启服务。"
        return ""

    def check_response(self, response):
        # Never relay response.text: gateways can echo headers or credentials in errors.
        if response.status_code == 401:
            raise ModelAPIError("模型接口鉴权失败，请检查服务端 API Key 是否正确或已失效。")
        if response.status_code == 403:
            raise ModelAPIError("当前 API Key 无模型调用权限，请检查科大平台的项目授权。")
        if response.status_code == 429:
            raise ModelAPIError("模型接口请求受限，请稍后重试或检查科大平台配额。")
        if response.status_code == 404:
            raise ModelAPIError("模型接口或模型不存在，请检查服务端 Base URL 和模型 ID。")
        response.raise_for_status()

    async def health(self, client):
        if self.configuration_error:
            return {"status": "configuration_required", "model_ready": False, "detail": self.configuration_error}
        try:
            response = await client.get(self.base_url + "/models", headers=self.headers, timeout=8)
            self.check_response(response)
            models = response.json()["data"]
            if not isinstance(models, list):
                raise ValueError("Invalid model list")
            ready = self.model in [item.get("id") for item in models if isinstance(item, dict)]
            return {"status": "ready" if ready else "model_unavailable", "model_ready": ready,
                    "detail": "" if ready else "当前 Key 的模型列表中没有配置的模型，请核对模型 ID 与项目授权。"}
        except ModelAPIError as exc:
            detail = str(exc)
        except (httpx.HTTPError, ValueError, KeyError, TypeError):
            detail = "无法获取模型列表，请检查服务端 Base URL、网络和模型服务。"
        return {"status": "model_unavailable", "model_ready": False, "detail": detail}

    async def complete(self, client, messages, *, temperature, max_tokens):
        if self.budget:
            async with self.budget.call():
                return await self._complete(client,messages,temperature=temperature,max_tokens=max_tokens)
        return await self._complete(client,messages,temperature=temperature,max_tokens=max_tokens)

    async def _complete(self, client, messages, *, temperature, max_tokens):
        if self.configuration_error:
            raise ModelAPIError(self.configuration_error)
        payload = {"model": self.model, "messages": messages, "temperature": temperature,
                   "top_p": 0.8, "max_tokens": max_tokens, "stream": False}
        # This is a local Qwen/vLLM extension, not part of the USTC gateway contract.
        if self.provider == "qwen":
            payload["chat_template_kwargs"] = {"enable_thinking": False}
        try:
            response = await client.post(self.base_url + "/chat/completions", json=payload, headers=self.headers)
            self.check_response(response)
            answer = response.json()["choices"][0]["message"]["content"]
            if not isinstance(answer, str):
                raise ValueError("Expected text content")
            answer = re.sub(r"<think>.*?</think>", "", answer, flags=re.S).strip()
            if not answer:
                raise ValueError("Empty model response")
            return answer
        except httpx.TimeoutException as exc:
            raise ModelAPIError("模型接口响应超时，请稍后重试。") from exc
        except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError) as exc:
            raise ModelAPIError("模型接口未就绪或返回异常，请检查服务端模型配置与网络。") from exc
