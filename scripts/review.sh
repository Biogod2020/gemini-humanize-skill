#!/usr/bin/env bash
# review.sh — have Gemini review material in a role. It gives opinions; it never edits your text.
#
#   review.sh ROLE [options] MATERIAL_FILE        (MATERIAL_FILE may be - for stdin)
#
# ROLE: reader | challenger | judge | meaning        (see roles/*.md)
# Options:
#   --persona TEXT   who Gemini stands in for ("Nature editor", "PI with no coding background", ...)
#   --goal TEXT      what the material is for and who reads it
#   --lang CODE      reply language (default: Chinese)
#   --max N          at most N points (default 8)
#   --against FILE   meaning role: the ORIGINAL text; MATERIAL_FILE is the REVISED one
#   --ref FILE       exemplar / background text, repeatable
#   --attach FILE    image or PDF sent along with the prompt, repeatable (proxy backend only)
#
# exit: 0 ok | 2 bad usage | 3 Gemini unavailable (carry on without it and say so)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
roles="$here/../roles"

role="${1:-}"; [ -n "$role" ] && shift
case "$role" in -h|--help|"") sed -n '2,17p' "$0"; exit 0 ;; esac
[ -r "$roles/$role.md" ] || { echo "unknown role: $role (have: $(cd "$roles" && ls | sed 's/\.md$//' | grep -v '^_' | tr '\n' ' '))" >&2; exit 2; }

persona="a smart reader who is not an expert in this topic"; goal="(not stated)"; lang="Chinese"; max=8
against=""; refs=(); attach=(); file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --persona) persona="${2:?}"; shift 2 ;;
    --goal)    goal="${2:?}"; shift 2 ;;
    --lang)    lang="${2:?}"; shift 2 ;;
    --max)     max="${2:?}"; shift 2 ;;
    --against) against="${2:?}"; shift 2 ;;
    --ref)     refs+=("${2:?}"); shift 2 ;;
    --attach)  attach+=(--attach "${2:?}"); shift 2 ;;
    -*)        echo "unknown option: $1" >&2; exit 2 ;;
    *)         file="$1"; shift ;;
  esac
done
[ -n "$file" ] || { echo "no MATERIAL_FILE" >&2; exit 2; }
[ "$role" != meaning ] || [ -n "$against" ] || { echo "meaning role needs --against ORIGINAL" >&2; exit 2; }

# Assemble in Python: plain string replacement, no shell/sed escaping surprises with the material.
prompt="$(python3 -I - "$roles" "$role" "$persona" "$goal" "$lang" "$max" "$file" "$against" "${refs[@]}" <<'PY'
import sys
roles, role, persona, goal, lang, mx, file, against, *refs = sys.argv[1:]
read = lambda p: sys.stdin.read() if p == "-" else open(p, encoding="utf-8").read()
subst = lambda s: (s.replace("{{PERSONA}}", persona).replace("{{GOAL}}", goal)
                    .replace("{{LANG}}", lang).replace("{{MAX_ITEMS}}", mx))
parts = [subst(open(f"{roles}/{role}.md", encoding="utf-8").read()).strip(),
         subst(open(f"{roles}/_common.md", encoding="utf-8").read()).strip()]
for r in refs:
    parts.append(f"=== REFERENCE: {r.rsplit('/', 1)[-1]} ===\n" + read(r).strip())
if against:
    parts.append("=== ORIGINAL ===\n" + read(against).strip())
    parts.append("=== REVISED ===\n" + read(file).strip())
else:
    parts.append("=== MATERIAL ===\n" + read(file).strip())
print("\n\n".join(parts))
PY
)" || exit 2

printf '%s' "$prompt" | "$here/gemini_call.sh" "${attach[@]}"
