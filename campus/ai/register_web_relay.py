"""Update the public Site after a free tunnel changes address; no model key leaves this PC."""
import argparse
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import getproxies
import httpx
from model_api import load_settings

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--url',required=True);args=parser.parse_args()
    settings=load_settings(Path(__file__).with_name('.env'))
    site=settings.get('CAMPUS_WEB_SITE_URL','').rstrip('/');token=settings.get('CAMPUS_RELAY_TOKEN','')
    if not site.startswith('https://') or len(token)<32:raise SystemExit('Web AI configuration is missing.')
    tunnel=urlparse(args.url)
    if tunnel.scheme!='https' or not tunnel.hostname.endswith('.trycloudflare.com'):raise SystemExit('Invalid tunnel URL.')
    try:
        # Use the user's existing system proxy for the public Site only.
        # Campus API and localhost connections retain their separate routing.
        proxy=settings.get('CAMPUS_WEB_PROXY') or getproxies().get('https')
        response=httpx.post(site+'/admin/relay',json={'url':args.url},headers={'Authorization':'Bearer '+token},timeout=20,proxy=proxy)
        if response.status_code!=200:raise SystemExit('Site registration unavailable (HTTP '+str(response.status_code)+'). Services remain local and running.')
        print('WEB_RELAY_REGISTERED')
    except httpx.HTTPError:raise SystemExit('Site is unreachable. Services remain local and running; retry registration after the network recovers.')

if __name__=='__main__':main()
