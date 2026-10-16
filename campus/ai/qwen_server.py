"""Single-GPU Transformers serving for this interview demo; vLLM can replace it."""
import asyncio
import os
from contextlib import asynccontextmanager

import torch
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from transformers import AutoModelForCausalLM, AutoTokenizer

MODEL_ID = os.getenv("QWEN_MODEL", "Qwen/Qwen3-8B")
MODEL_PATH = os.getenv("QWEN_MODEL_PATH", MODEL_ID)


@asynccontextmanager
async def lifespan(app):
    app.state.tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    app.state.model = AutoModelForCausalLM.from_pretrained(MODEL_PATH, dtype=torch.bfloat16, device_map="auto")
    app.state.model.eval()
    app.state.lock = asyncio.Lock()
    yield


app = FastAPI(title="Campus Qwen model service", lifespan=lifespan)


class Message(BaseModel):
    role: str
    content: str


class Completion(BaseModel):
    model: str
    messages: list[Message]
    max_tokens: int = Field(default=640, ge=1, le=1024)
    temperature: float = Field(default=.7, gt=0, le=2)
    top_p: float = Field(default=.8, gt=0, le=1)
    chat_template_kwargs: dict = Field(default_factory=dict)


@app.get("/v1/models")
async def models():
    return {"data": [{"id": MODEL_ID, "object": "model"}]}


def generate(request):
    tokenizer = app.state.tokenizer
    messages = [m.model_dump() for m in request.messages]
    while True:
        inputs = tokenizer.apply_chat_template(messages, tokenize=True, add_generation_prompt=True,
                                               enable_thinking=False, return_dict=True, return_tensors="pt")
        if inputs.input_ids.shape[-1] + request.max_tokens <= 8192 or len(messages) <= 2:
            break
        # Retain role instructions, current evidence, and the newest question.
        del messages[1: min(3, len(messages) - 1)]
    if inputs.input_ids.shape[-1] + request.max_tokens > 8192:
        raise ValueError("Context exceeds demo limit of 8192 tokens")
    inputs = inputs.to(app.state.model.device)
    with torch.inference_mode():
        output = app.state.model.generate(**inputs, max_new_tokens=request.max_tokens,
                                         do_sample=True, temperature=request.temperature, top_p=request.top_p)
    result = tokenizer.decode(output[0][inputs.input_ids.shape[-1]:], skip_special_tokens=True)
    return {"id": "campus-qwen", "object": "chat.completion", "model": MODEL_ID,
            "choices": [{"index": 0, "message": {"role": "assistant", "content": result}, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": inputs.input_ids.shape[-1], "completion_tokens": output.shape[-1] - inputs.input_ids.shape[-1]}}


@app.post("/v1/chat/completions")
async def completion(request: Completion):
    if request.model != MODEL_ID:
        raise HTTPException(404, "Unknown model")
    try:
        async with app.state.lock:
            return await asyncio.to_thread(generate, request)
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
