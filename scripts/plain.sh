#!/usr/bin/env bash
# plain.sh — ask Gemini (cold reader) to rewrite a draft in plain language.
#
#   plain.sh [--audience TEXT] [--lang CODE|NAME] [FILE]    (stdin if no FILE)
#
# stdout: Gemini's "REWRITE ... STUMBLES ..." reply
# stderr: WARN lines for code spans / numbers from the draft missing in the rewrite
# exit  : 0 ok | 2 bad usage | 3 Gemini unavailable or failed (fall back to your own rewrite)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template="$here/../references/editor-prompt.md"
[ -r "$template" ] || { echo "missing $template" >&2; exit 2; }

audience="a smart reader who is not an expert in this topic"
lang="the same language as the draft"
file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --audience) audience="${2:?--audience needs a value}"; shift 2 ;;
    --lang)     lang="${2:?--lang needs a value}"; shift 2 ;;
    -h|--help)  sed -n '2,9p' "$0"; exit 0 ;;
    -*)         echo "unknown option: $1" >&2; exit 2 ;;
    *)          file="$1"; shift ;;
  esac
done

draft="$(cat -- "${file:--}")" || exit 2
[ -n "$draft" ] || { echo "empty draft" >&2; exit 2; }

# Locate the CLI. `gemini` is often only a shell alias, so also accept GEMINI_BIN.
if [ -n "${GEMINI_BIN:-}" ]; then gem=($GEMINI_BIN)
elif command -v gemini >/dev/null 2>&1; then gem=(gemini)
else echo "gemini CLI not found (set GEMINI_BIN)" >&2; exit 3; fi

# ~/.gemini on NFS breaks its lock files; use local disk when the home dir is not local.
if [ -z "${GEMINI_CLI_HOME:-}" ] && [ "$(stat -f -c %T "$HOME" 2>/dev/null)" = "nfs" ]; then
  export GEMINI_CLI_HOME="/tmp/gemini_home_$USER"
  mkdir -p "$GEMINI_CLI_HOME"
fi

# Fill the template. Bash replacement avoids sed/regex escaping problems with the draft.
prompt="$(cat -- "$template")"
prompt="${prompt//\{\{AUDIENCE\}\}/$audience}"
prompt="${prompt//\{\{LANG\}\}/$lang}"
prompt="${prompt//\{\{DRAFT\}\}/$draft}"

# Per-model timeout: a model can hang inside the CLI while others answer in seconds.
# Order: GEMINI_MODEL, then the fallbacks (default: two older flash models; the rolling -latest alias can point at the hanging one).
timeout_s="${GEMINI_TIMEOUT:-60}"
models=(${GEMINI_MODEL:-} ${GEMINI_FALLBACK_MODELS-gemini-3.5-flash gemini-3-flash-preview})
[ ${#models[@]} -gt 0 ] || models=("")   # empty = CLI default

# Run from an empty dir so the CLI does not wander into the project and call tools.
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
cd "$work" || exit 3

out=""
for m in "${models[@]}"; do
  args=(-p "$prompt")
  [ -n "$m" ] && args=(-m "$m" "${args[@]}")
  if out="$(timeout "$timeout_s" "${gem[@]}" "${args[@]}" 2>/dev/null)" && [[ "$out" == *REWRITE* ]]; then
    break
  fi
  out=""
done
[ -n "$out" ] || { echo "gemini failed or returned no REWRITE (tried: ${models[*]:-default})" >&2; exit 3; }

out="REWRITE${out#*REWRITE}"   # drop any chatter before the marker
printf '%s\n' "$out"

# Advisory fact guard: things that must survive a rewrite.
rewrite="${out#*REWRITE}"; rewrite="${rewrite%%STUMBLES*}"
norm() { tr -d ',' <<<"$1"; }
rw="$(norm "$rewrite")"
{
  grep -oE '`[^`]+`' <<<"$draft" | sort -u
  norm "$draft" | grep -oE '[0-9]+(\.[0-9]+)?%?' | sort -u
} | while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  grep -qF -- "$tok" <<<"$rw" || echo "WARN missing in rewrite: $tok" >&2
done
exit 0
