#!/usr/bin/env bash
# Regression tests for scripts/facts.sh. Run: tests/test_facts.sh
cd "$(dirname "$0")/.." || exit 1
fail=0
t() { # name, original, revised, expected exit, expected WARN substring ("" = none)
  local o r; o="$(mktemp)"; r="$(mktemp)"; printf '%s' "$2" >"$o"; printf '%s' "$3" >"$r"
  out="$(scripts/facts.sh "$o" "$r")"; code=$?
  if [ "$code" != "$4" ] || { [ -n "$5" ] && [[ "$out" != *"$5"* ]]; }; then
    echo "FAIL $1 (exit $code): $out"; fail=1; else echo "ok   $1"; fi
  rm -f "$o" "$r"
}
t cjk-adjacent-number   '共有3862个样本,第3章讲了约20s开销。' '共有3862个样本。' 1 'missing in revised: 3'
t cjk-adjacent-20       '约20s开销' '开销' 1 'missing in revised: 20'
t code-span-dropped     '改 `num_workers=8` 即可' '改一下参数即可' 1 '`num_workers=8`'
t comma-number-same     '共 3,862 个' '共 3862 个' 0 ''
t number-added          '耗时 12 秒' '耗时 12 秒,共 30 个' 1 'only in revised: 30'
t intensifier-added     '耗时降低了' '耗时显著降低了' 1 'intensifier only in revised: 显著'
t unchanged             '已修复 `a.py`,耗时 412s 降到 138s(-66.5%)。' '`a.py` 已修好。耗时从 412s 降到 138s(-66.5%)。' 0 ''
exit $fail
