import importlib
import httpx
from fastapi.testclient import TestClient

def test_relay_auth_allowlist_body_limit_and_offline(monkeypatch):
    monkeypatch.setenv('CAMPUS_RELAY_TOKEN','relay-test-token-not-real-'+'x'*32)
    import web_relay
    module=importlib.reload(web_relay)
    with TestClient(module.app) as client:
        seen=[]
        def send(request):
            seen.append(request)
            assert request.url.host=='127.0.0.1' and request.url.port==8787
            assert 'authorization' not in request.headers
            return httpx.Response(429,json={'detail':'slow down'},headers={'Retry-After':'12'})
        module.app.state.client=httpx.AsyncClient(transport=httpx.MockTransport(send))
        assert client.get('/health').status_code==401
        headers={'Authorization':'Bearer '+module.TOKEN}
        assert client.get('/config',headers=headers).status_code==404
        assert client.post('/chat',content='x'*32769,headers=headers).status_code==413
        assert not seen
        response=client.post('/chat',json={'npc_id':'library','message':'hi'},headers=headers)
        assert response.status_code==429 and response.headers['retry-after']=='12'
        assert len(seen)==1
        def disconnected(request):raise httpx.ConnectError('offline')
        module.app.state.client=httpx.AsyncClient(transport=httpx.MockTransport(disconnected))
        assert client.get('/health',headers=headers).json()['status']=='offline'
