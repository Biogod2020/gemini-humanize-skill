# gemini-humanize-skill

让 Gemini 当"局外人"审 agent 的产出，让结果对人更直观、更好懂。

**分工**：agent 写和改；Gemini 没有任何上下文，扮演冷读者、挑错者、评审，只给意见；agent 逐条核实后才采纳。Gemini 不直接改正文，因为它会加强调词、编数字、悄悄改含义。

## 什么时候用

- 用户说"看不懂""说人话"：agent 重写说明，Gemini 冷读，看它读懂的和本意是否一致。
- 重要产物（论文、图、方案、对外文案）交付前，让 Gemini 扮演编辑、审稿人、读者各审一遍。
- 对根因诊断、"已修好"、不可逆操作，让 Gemini 找盲点。
- 日常回复、小改动、能直接跑测试验证的，不用。

## 用法

```bash
scripts/review.sh reader --persona "不熟悉工程的生信研究者" --goal "让他决定是否接受 20s 启动开销" reply.md
scripts/review.sh judge --persona "Nature 编辑" --goal "判断主图是否一眼讲清" --attach fig1.png caption.md
scripts/review.sh challenger --persona "深度学习工程师" --goal "判断根因诊断是否可靠" diagnosis.md
scripts/review.sh meaning --against old.md new.md
scripts/facts.sh old.md new.md        # 数字、路径、命令、强调词是否变化
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

## 来由

这套分工来自一次真实的论文写作：让 Gemini 直接改写全文时，它加了强调词、改了 3 处含义；改成"Claude 亲自写、Gemini 角色审、Claude 核实后采纳"后效果稳定。
