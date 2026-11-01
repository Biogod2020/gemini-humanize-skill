#!/usr/bin/env bash
# gemini_call.sh — send a prompt (stdin) to Gemini, print the text reply (stdout).
#
#   gemini_call.sh [--attach FILE]...  < prompt.txt
#
# Backend A (when GEMINI_PROXY_URL is set): native generateContent endpoint, e.g. a local
#   CLIProxyAPI at http://127.0.0.1:8317. Key from GEMINI_PROXY_KEY or the file
#   GEMINI_PROXY_KEY_FILE, sent in the x-goog-api-key header (never in the URL).
#   --attach sends images / PDFs inline.
# Backend B (otherwise): the Gemini CLI (GEMINI_BIN or `gemini`). Text only.
#
# Settings may live in ${GEMINI_HUMANIZE_ENV:-~/.config/gemini-humanize.env} (plain KEY=VALUE lines).
# Env: GEMINI_MODEL (default gemini-3.8-flash-high), GEMINI_TIMEOUT (default 120 s)
# exit: 0 ok | 2 bad usage | 3 Gemini unavailable or failed
set -uo pipefail

envfile="${GEMINI_HUMANIZE_ENV:-$HOME/.config/gemini-humanize.env}"
[ -r "$envfile" ] && { set -a; . "$envfile"; set +a; }

attach=()
while [ $# -gt 0 ]; do
  case "$1" in
    --attach) [ -r "${2:-}" ] || { echo "cannot read attachment: ${2:-}" >&2; exit 2; }; attach+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

timeout_s="${GEMINI_TIMEOUT:-120}"
prompt="$(cat)"
[ -n "$prompt" ] || { echo "empty prompt" >&2; exit 2; }

if [ -n "${GEMINI_PROXY_URL:-}" ]; then
  key="${GEMINI_PROXY_KEY:-}"
  [ -z "$key" ] && [ -r "${GEMINI_PROXY_KEY_FILE:-/nonexistent}" ] && key="$(<"$GEMINI_PROXY_KEY_FILE")"
  [ -n "$key" ] || { echo "no proxy key (GEMINI_PROXY_KEY / GEMINI_PROXY_KEY_FILE)" >&2; exit 3; }
  model="${GEMINI_MODEL:-gemini-3.8-flash-high}"
  resp="$(printf '%s' "$prompt" \
    | python3 -I -c '
import base64, json, subprocess, sys
parts = [{"text": sys.stdin.read()}]
for f in sys.argv[1:]:
    mime = subprocess.run(["file", "--mime-type", "-b", f], stdout=subprocess.PIPE, universal_newlines=True).stdout.strip() or "application/octet-stream"
    parts.append({"inline_data": {"mime_type": mime, "data": base64.b64encode(open(f, "rb").read()).decode()}})
print(json.dumps({"contents": [{"role": "user", "parts": parts}]}))' "${attach[@]}" \
    | curl -sS --noproxy '*' -m "$timeout_s" -H "x-goog-api-key: $key" -H 'Content-Type: application/json' \
        -d @- "${GEMINI_PROXY_URL%/}/v1beta/models/${model}:generateContent")" \
    || { echo "proxy request failed" >&2; exit 3; }
  printf '%s' "$resp" | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
try:
    parts = d["candidates"][0]["content"]["parts"]
    print("".join(p.get("text", "") for p in parts if not p.get("thought")).strip())
except Exception:
    sys.stderr.write("bad reply: " + json.dumps(d)[:300] + "\n"); sys.exit(3)
' || exit 3
  exit 0
fi

[ ${#attach[@]} -eq 0 ] || { echo "attachments need the proxy backend (set GEMINI_PROXY_URL)" >&2; exit 3; }
if [ -n "${GEMINI_BIN:-}" ]; then gem=($GEMINI_BIN)
elif command -v gemini >/dev/null 2>&1; then gem=(gemini)
else echo "no backend: set GEMINI_PROXY_URL or install the gemini CLI" >&2; exit 3; fi
if [ -z "${GEMINI_CLI_HOME:-}" ] && [ "$(stat -f -c %T "$HOME" 2>/dev/null)" = "nfs" ]; then
  export GEMINI_CLI_HOME="/tmp/gemini_home_$USER"; mkdir -p "$GEMINI_CLI_HOME"   # NFS breaks its lock files
fi
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT; cd "$work" || exit 3             # keep the CLI out of the project
args=(-p "$prompt"); [ -n "${GEMINI_MODEL:-}" ] && args=(-m "$GEMINI_MODEL" "${args[@]}")
out="$(timeout "$timeout_s" "${gem[@]}" "${args[@]}" 2>/dev/null)" && [ -n "$out" ] || exit 3
printf '%s\n' "$out"
