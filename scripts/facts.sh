#!/usr/bin/env bash
# facts.sh — mechanical check that a revision kept the hard facts of the original.
#
#   facts.sh ORIGINAL REVISED
#
# Prints a WARN line for every `code span`, URL, or number in ORIGINAL that is absent from REVISED,
# and for every number or intensifier that REVISED adds. Advisory: a human/agent decides.
# exit: 0 nothing flagged | 1 something flagged | 2 bad usage
set -uo pipefail
[ $# -eq 2 ] && [ -r "$1" ] && [ -r "$2" ] || { sed -n '2,9p' "$0"; exit 2; }
python3 -I - "$1" "$2" <<'PY'
import re, sys
a, b = (open(p, encoding="utf-8").read() for p in sys.argv[1:3])
norm = lambda s: s.replace(",", "")
def toks(s):
    s = re.sub(r"(?m)^\s*(?:[-*]\s+)?\(?\d{1,2}[.)、]\s*", "", norm(s))   # drop list ordinals ("1.", "2)")
    spans = set(re.findall(r"`[^`\n]+`", s)) | set(re.findall(r"https?://[^\s)>\]]+", s))
    nums = set(re.findall(r"(?<![A-Za-z0-9_.])\d+(?:\.\d+)?%?", s))
    return spans, nums
sa, na = toks(a); sb, nb = toks(b)
flag = 0
for t in sorted(sa - sb) + sorted(na - nb):
    print(f"WARN missing in revised: {t}"); flag = 1
for t in sorted(nb - na):
    print(f"WARN number only in revised: {t}"); flag = 1
boost = r"\b(very|highly|significantly|substantially|robust(?:ly)?|critical(?:ly)?|clearly|successfully|completely|fully|only|dramatically)\b|非常|极其|显著|完全|成功地|大幅"
for m in sorted({m.group(0).lower() for m in re.finditer(boost, b, re.I)} - {m.group(0).lower() for m in re.finditer(boost, a, re.I)}):
    print(f"WARN intensifier only in revised: {m}"); flag = 1
sys.exit(flag)
PY
