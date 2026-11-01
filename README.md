# gemini-humanize-skill

让 Gemini 当"局外人"审 agent 的重要产物，agent 逐条核实后才采纳。

**分工**：agent 写和改；Gemini 没有任何上下文，扮演评审、挑错者、冷读者，只给意见。Gemini 不直接改正文，因为它会加强调词、编数字、悄悄改含义。

## 什么时候用

- 论文、骨架、图、方案、对外文案交付前：让 Gemini 扮演编辑、苛刻审稿人、普通读者各审一遍。
- 对根因诊断、"已修好"、不可逆操作：让 Gemini 找盲点。
- 改写或润色之后：让 Gemini 只查含义有没有被改。
- 日常回复、小改动、能直接跑测试验证的，不用。

用户说"看不懂"时，不调用 Gemini，SKILL.md 里有一份"说人话"写作规则，agent 直接按规则重写。

## 用法

```bash
scripts/review.sh judge --persona "Nature 编辑" --goal "判断主图是否一眼讲清" --attach fig1.png caption.md
scripts/review.sh challenger --persona "深度学习工程师" --goal "判断根因诊断是否可靠" diagnosis.md
scripts/review.sh reader --persona "不熟悉本领域的读者" --goal "读懂 README" README.md
scripts/review.sh meaning --against old.md new.md
scripts/facts.sh old.md new.md        # 数字、路径、命令、强调词是否变化
tests/test_facts.sh                   # facts.sh 的回归测试
```

完整流程与判断标准见 [SKILL.md](SKILL.md)，角色提示词在 [roles/](roles/)，意见台账格式见 [references/ledger.md](references/ledger.md)。

## 配置

`~/.config/gemini-humanize.env`：

```
GEMINI_PROXY_URL=http://127.0.0.1:8317      # Gemini 原生接口，如本机 CLIProxyAPI；支持图片/PDF
GEMINI_PROXY_KEY_FILE=/path/to/key_file
GEMINI_MODEL=gemini-3.8-flash-high
```

不设置 `GEMINI_PROXY_URL` 时退回 `gemini` 命令行（只支持文字）。

## 安装

```bash
git clone https://github.com/Biogod2020/gemini-humanize-skill ~/.claude/skills/gemini-humanize-skill
```

## 隐私

发给 Gemini 的材料会离开本机。先去掉密钥、令牌和个人信息。

## 实测结论

- **来由**：这套分工来自一次真实的论文写作。让 Gemini 直接改写全文时，它加了强调词、改了 3 处含义；改成"agent 写、Gemini 角色审、agent 核实后采纳"后效果稳定。
- **"看不懂"场景不值得调用 Gemini**：Haiku 和 gpt-6.1-terra 各跑 3 份黑话材料，有无 Gemini 冷读流程的回复经盲评为 3 比 3，但带 Gemini 的流程慢 8 到 12 倍，所以降级成写作规则。
- **agent 会跳步**：流程里排在中间的"必做"步骤，模型常常省略；Gemini 的修改建议里常夹带原文没有的事实，所以每条都要核实。
