# codex-gemini-loop → plain-talk

让 agent 在回复用户之前，先把草稿交给 **没有任何上下文的 Gemini** 当"冷读者"：它用大白话重写，并指出新手会卡住的地方。agent 再核对事实没变，然后才发给用户。

Before an agent sends a non-trivial result, Gemini reads the draft cold, rewrites it in plain language, and lists where a newcomer stumbles. The agent checks no fact changed, then replies.

## 为什么用 Gemini，而不是让 agent 自己改写

写草稿的 agent 太熟悉任务，看不出哪里难懂。Gemini 没看过任何过程，它卡住的地方就是用户会卡住的地方。同类 skill（`eli5`、`plain-english` 等）都是同一个模型自己改写，没有这个"冷读者"视角。

## 用法

```bash
scripts/plain.sh draft.md
scripts/plain.sh --audience "课题组PI，不写代码" --lang zh draft.md
cat draft.md | scripts/plain.sh
```

输出 `REWRITE`（改写稿）和 `STUMBLES`（卡点清单）。脚本还会对草稿里的反引号代码、路径、数字做检查，改写稿里丢了的会在 stderr 打印 `WARN`。Gemini 不可用时退出码为 3，agent 自己改写即可，不阻塞回复。

完整流程见 [SKILL.md](SKILL.md)，给 Gemini 的提示词见 [references/editor-prompt.md](references/editor-prompt.md)。

## 安装

```bash
# Claude Code
git clone https://github.com/Biogod2020/codex-gemini-loop ~/.claude/skills/codex-gemini-loop
# Codex
git clone https://github.com/Biogod2020/codex-gemini-loop ~/.codex/skills/codex-gemini-loop
```

需要已安装并登录的 Gemini CLI。可选环境变量：`GEMINI_BIN`、`GEMINI_MODEL`、`GEMINI_FALLBACK_MODELS`、`GEMINI_TIMEOUT`。

## 隐私

草稿会发给 Gemini。发送前去掉密钥、令牌和个人信息。
