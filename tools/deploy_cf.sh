#!/usr/bin/env bash
# Deploy the static website (tools/site.sh -> out/site) to Albert's Cloudflare as a
# static-assets Worker: https://robbie-n1.bauldejuegos.workers.dev
# (Workers, not Pages: Albert's token can deploy Workers scripts but not Pages projects.)
# Needs CLOUDFLARE_API_TOKEN in the environment (never in the repo); the account ID is
# looked up from the token when CLOUDFLARE_ACCOUNT_ID isn't set. Config: tools/cloudflare/wrangler.toml
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${CLOUDFLARE_API_TOKEN:?not set: add it to the cloud environment's variables}"
[[ -f "$ROOT/out/site/index.html" ]] || { echo "run tools/site.sh first"; exit 1; }
if [[ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  CLOUDFLARE_ACCOUNT_ID=$(curl -sS "https://api.cloudflare.com/client/v4/accounts?per_page=5" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)['result'][0]['id'])")
  export CLOUDFLARE_ACCOUNT_ID
fi
export WRANGLER_SEND_METRICS=false
cd "$ROOT/tools/cloudflare"
npx --yes wrangler@4 deploy 2>&1 | grep -E "Uploaded|Deployed|https://|ERROR|✘" || true
code=$(curl -sS -o /dev/null -w "%{http_code}" https://robbie-n1.bauldejuegos.workers.dev/)
echo "live check: HTTP $code"
[[ "$code" == "200" ]]
