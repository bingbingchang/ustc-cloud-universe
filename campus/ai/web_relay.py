"""Authenticated tunnel endpoint; the existing AI backend stays loopback-only."""
import hmac
from contextlib import asynccontextmanager
from pathlib import Path
import httpx
from fastapi import FastAPI, Request
from starlette.responses import JSONResponse, Response
from model_api import load_settings

SETTINGS=load_settings(Path(__file__).with_name('.env'))
TOKEN=SETTINGS.get('CAMPUS_RELAY_TOKEN','').strip()
BACKEND='http://127.0.0.1:8787'

@asynccontextmanager
async def lifespan(app):
    if len(TOKEN)<32:raise RuntimeError('Configure CAMPUS_RELAY_TOKEN in the local AI .env before starting the relay.')
    async with httpx.AsyncClient(timeout=100,follow_redirects=False) as client:
        app.state.client=client
        yield

app=FastAPI(title='Campus Web Relay',docs_url=None,redoc_url=None,openapi_url=None,lifespan=lifespan)

@app.api_route('/{path:path}',methods=['GET','POST','PUT','DELETE','OPTIONS'])
async def relay(path:str,request:Request):
    supplied=request.headers.get('authorization','')
    if not TOKEN or not hmac.compare_digest(supplied,'Bearer '+TOKEN):
        return JSONResponse({'detail':'Unauthorized'},status_code=401)
    allowed={'GET':{'health','npcs'},'POST':{'chat','agent'}}
    if path not in allowed.get(request.method,set()):return JSONResponse({'detail':'Not found'},status_code=404)
    body=bytearray()
    async for chunk in request.stream():
        body.extend(chunk)
        if len(body)>32768:return JSONResponse({'detail':'Question too long'},status_code=413)
    try:
        headers={'Content-Type':'application/json'}
        personal_key=request.headers.get('X-Campus-API-Key')
        if personal_key is not None:
            if len(personal_key)>512 or not personal_key or any(ord(c)<33 or ord(c)>126 for c in personal_key):
                return JSONResponse({'detail':'API Key 格式无效。'},status_code=400)
            headers['X-Campus-API-Key']=personal_key
        upstream=await request.app.state.client.request(request.method,BACKEND+'/'+path,content=bytes(body),headers=headers)
        headers={'Cache-Control':'no-store'}
        if 'retry-after' in upstream.headers:headers['Retry-After']=upstream.headers['retry-after']
        return Response(upstream.content,status_code=upstream.status_code,media_type='application/json',headers=headers)
    except httpx.HTTPError:
        return JSONResponse({'status':'offline','model_ready':False,'detail':'校园 AI 服务暂时离线。'},status_code=503)
