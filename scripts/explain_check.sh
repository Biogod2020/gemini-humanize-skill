#!/usr/bin/env bash
# explain_check.sh — the "user can't follow it" flow: Gemini cold-reads a text; optionally also
# checks that a rewrite kept the original's facts.
#
#   explain_check.sh FILE --persona TEXT --goal TEXT [--max N]                 # step 1: cold-read the original
#   explain_check.sh DRAFT --against ORIGINAL --persona TEXT --goal TEXT        # step 3: cold-read the rewrite + fact check
#
# exit: 0 clean | 1 facts.sh flagged something | 3 Gemini unavailable (tell the user)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ $# -ge 1 ] && [ -r "$1" ] || { sed -n '2,9p' "$0"; exit 2; }
file="$1"; shift
against=""; rest=()
while [ $# -gt 0 ]; do
  case "$1" in --against) against="${2:?}"; shift 2 ;; *) rest+=("$1"); shift ;; esac
done

echo "##### COLD READER (Gemini) #####"
"$here/review.sh" reader "${rest[@]}" "$file"; rc=$?
[ $rc -eq 0 ] || echo "(Gemini cold read failed, exit $rc — tell the user this was not cold-read)" >&2

fc=0
if [ -n "$against" ]; then
  echo; echo "##### FACT CHECK (original vs draft) #####"
  "$here/facts.sh" "$against" "$file"; fc=$?
  [ $fc -eq 0 ] && echo "no flags"
fi
[ $rc -ne 0 ] && exit $rc
exit $fc
