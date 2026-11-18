"""One budget for every actual model call made by chat and the action agent."""
import asyncio
import math
import time
from collections import deque
from contextlib import asynccontextmanager

class ModelRateLimitError(Exception):
    def __init__(self, detail, retry_after):
        super().__init__(detail)
        self.retry_after = retry_after
        self.status_code = 429

class CallBudget:
    def __init__(self, concurrency=2, per_minute=10, clock=time.monotonic):
        self.concurrency=max(1,concurrency)
        self.per_minute=max(1,per_minute)
        self.clock=clock
        self.started=deque()
        self.active=0
        self.lock=asyncio.Lock()

    @asynccontextmanager
    async def call(self):
        async with self.lock:
            now=self.clock()
            while self.started and self.started[0]<=now-60:self.started.popleft()
            if self.active>=self.concurrency:
                raise ModelRateLimitError("校园 AI 正在回答其他问题，请稍后再试。",5)
            if len(self.started)>=self.per_minute:
                raise ModelRateLimitError("校园 AI 本分钟请求已满，请稍后再试。",max(1,math.ceil(60-now+self.started[0])))
            self.started.append(now);self.active+=1
        try:
            yield
        finally:
            async with self.lock:self.active-=1
