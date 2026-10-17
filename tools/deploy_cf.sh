#!/usr/bin/env bash
# Deploy the static website (tools/site.sh -> out/site) to Albert's Cloudflare Pages.
# Needs CLOUDFLARE_API_TOKEN (permission: Account > Cloudflare Pages > Edit) and
# CLOUDFLARE_ACCOUNT_ID, set as environment variables on the cloud environment (never in the repo).
# Usage: tools/deploy_cf.sh [project=robbie-n1]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-robbie-n1}"
: "${CLOUDFLARE_API_TOKEN:?not set: add it to the cloud environment's variables}"
: "${CLOUDFLARE_ACCOUNT_ID:?not set: add it to the cloud environment's variables}"
[[ -f "$ROOT/out/site/index.html" ]] || { echo "run tools/site.sh first"; exit 1; }
WRANGLER="npx --yes wrangler@4"
# Create the project the first time (an error just means it exists already).
$WRANGLER pages project create "$PROJECT" --production-branch main > /dev/null 2>&1 || true
$WRANGLER pages deploy "$ROOT/out/site" --project-name "$PROJECT" --branch main --commit-dirty=true
echo "live at https://$PROJECT.pages.dev"
