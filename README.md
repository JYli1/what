# what

> 让终端报错自己解释自己。

`what` 是一个终端命令智能分析工具（支持 Linux / Windows PowerShell）：执行任意命令后输入 `what`，它会自动读取上一条命令、退出码和终端输出，交给 LLM 分析，然后用中文告诉你发生了什么、为什么失败、下一步该怎么做。

它适合这些场景：

- 开发调试：快速定位构建失败、依赖缺失、运行时报错。
- Linux / 运维排障：分析服务状态、权限、网络、资源和日志线索。
- CTF / 授权渗透测试：总结扫描结果、提取漏洞线索、给出下一步枚举方向。
- 长输出快速总结：不用在几百行日志里手动翻关键错误。

已经实现：

- 自动捕获上一条命令、退出码和输出。
- 默认流式 Markdown 渲染（`rich` Live 实时刷新），打字机效果。
- 兼容常见 LLM API，可接 DeepSeek、Ollama 等服务。
- 内置 `default` / `pentest` / `dev` / `ops` / `custom` 工作方向。
- 支持 `--smart` 本地智能缩减长输出，节省 token。
- 支持 `--show` 只查看捕获内容，不调用 API。
- 完整日志与 LLM 对话原文记录，方便排查和复盘。
- 支持 zsh / bash hook，安装后自然融入终端工作流。
- Windows PowerShell 原生支持（基于 History + 重执行捕获）。

```bash
$ npm run build
...
error: Cannot find module 'xxx'

$ what
# 直接告诉你错误原因、修复命令和下一步检查点
```

## 更新日志

### v0.3 — 流式 Markdown 渲染 + Windows 钩子重构

- **默认输出改为流式 Markdown 渲染**：使用 `rich` Live 实时刷新，打字机效果，不再等待完整响应后一次性渲染。
- **Windows 输出捕获重构**：移除 Transcript 录制方案，改为通过 PowerShell History + 重执行命令捕获输出，更稳定可靠。
- **Windows 钩子精简**：不再依赖 PSReadLine Enter 键拦截和 Transcript，改用 prompt 函数 + Get-History，兼容性更好。
- **BOM 兼容**：`read_file` 使用 `utf-8-sig` 编码，解决 Windows 下 PowerShell 写入文件带 BOM 导致解析失败的问题。
- **Prompt 优化**：回答要求调整为"第一行立即给结论"，减少冗余前缀。
- `--stream` 现在明确表示"流式纯文本（无渲染）"，`--plain` 表示"非流式纯文本"。

---

## 安装

```bash
git clone https://github.com/your/what.git
cd what
./install.sh
```

安装后：
```bash
what --setup          # 配置 API Key
source ~/.zshrc       # zsh 用户
source ~/.bashrc      # bash 用户
```

### Windows (PowerShell)

```powershell
git clone https://github.com/your/what.git
cd what\windows
.\install.ps1
```

安装后：
```powershell
what --setup          # 配置 API Key
. $PROFILE            # 重新加载配置（或重启 PowerShell）
```

## 更新

### Linux

```bash
cd what
git pull
./install.sh
```

### Windows (PowerShell)

```powershell
cd what\windows
git pull
.\install.ps1
```

更新后无需重新配置，`~/.what/config` 会保留。

## 使用

```bash
$ rustscan -a 10.216.75.108 --json
error: unexpected argument '--json' found
...

$ what
──────────────────────────────────────────────────
$ rustscan -a 10.216.75.108 --json  (exit: 1)
──────────────────────────────────────────────────

[LLM Markdown 分析结果]
```

## 全部参数

### 分析模式

| 参数 | 作用 | 例子 |
|------|------|------|
| `what` | 分析上一条命令，默认流式 Markdown 渲染 | `what` |
| `-q`, `--question "问题"` | 带自定义追问，用引号包裹 | `what -q "怎么修复 Permission denied"` |

### 输出控制

| 参数 | 作用 | 例子 |
|------|------|------|
| `--smart` | 启用智能缩减，只发送提炼后的关键输出 | `what --smart` |
| `--stream` | 流式纯文本输出（无 Markdown 渲染） | `what --stream` |
| `--plain` | 非流式纯文本输出 | `what --plain` |
| `--raw` | 兼容旧参数：当前默认就是发送完整输出 | `what --raw` |
| `--md` | 兼容旧参数：当前默认就是 Markdown 渲染 | `what --md` |
| `--show` | 只查看捕获的原始命令+输出，不调 LLM | `what --show` |
| `--no-color` | 纯文本，禁用所有颜色 | `what --no-color` |

### 调试

| 参数 | 作用 | 例子 |
|------|------|------|
| `-d`, `--debug` | 日志同步输出到 stderr | `what -d` |

### 手动测试（无需 hook）

| 参数 | 作用 | 例子 |
|------|------|------|
| `--cmd` | 手动指定命令文本 | `--cmd 'ls -la'` |
| `--output` | 手动指定输出文本 | `--output 'error: ...'` |
| `--output-file` | 从文件读取输出 | `--output-file /tmp/out.txt` |
| `--exit-code` | 手动指定退出码（默认 0） | `--exit-code 1` |

### 配置

| 参数 | 作用 |
|------|------|
| `--setup` | 交互式配置向导 |

### 可组合示例

```bash
# 默认 Markdown 渲染 + 自定义问题（-q 不怕特殊字符）
what -q "这个 [!] 怎么修"

# 手动测试 + 智能缩减 + 调试日志
what --cmd 'nmap -p 80 10.0.0.1' --output-file /tmp/scan.txt --exit-code 0 --smart -d

# 需要实时输出时使用流式纯文本
what --stream

# 只看捕获了什么，不消耗 API
what --show
```

## 配置

`~/.what/config`，兼容常见 LLM API：

```ini
api_base = https://api.openai.com/v1    # 也支持 DeepSeek、Ollama
api_key = sk-your-key-here
model = gpt-4o-mini
max_output_chars = 20000
profile = pentest
custom_instruction = 优先从信息收集、漏洞线索和下一步命令角度总结
```

环境变量覆盖：`WHAT_API_KEY`、`WHAT_MODEL` 等。回答语言固定为中文。

### 工作方向

通过 `what --setup` 选择，也可以直接编辑 `~/.what/config`：

| profile | 适用场景 | 关注点 |
|---------|----------|--------|
| `default` | 通用命令分析 | 命令做了什么、结果如何 |
| `pentest` | 授权渗透测试/靶场/CTF | 信息收集、漏洞线索、下一步枚举/验证命令 |
| `dev` | 开发调试 | 报错原因、依赖问题、修复命令 |
| `ops` | 运维排障 | 服务状态、网络、权限、资源、日志线索 |
| `custom` | 自定义方向 | 使用 `custom_instruction` 描述你的偏好 |

例如：

```ini
profile = pentest
custom_instruction = 我主要在打 Web 靶场，请优先给下一步可执行命令，不要讲太多原理。
```

## 输出发送策略

默认发送完整捕获输出，避免智能缩减误删关键内容；当输出超过 `max_output_chars` 时，会保留头尾并截断中间。

如需节省 token 或处理超长输出，可以手动启用智能缩减：

```bash
what --smart
```

智能缩减会本地提取关键错误/警告、提示、头尾和部分采样内容。

| 场景 | Prompt 策略 |
|------|------------|
| 检测到错误 + 退出码非 0 | 直接问原因和修复方法 |
| 退出码非 0 但无错误关键字 | 通用失败分析 |
| 成功但有警告 | 总结结果 + 警告处理建议 |
| 成功无警告 | 简洁总结 |

`--raw` 仅为兼容旧版本保留；当前默认行为已经是发送完整输出。

## Prompt 构建策略

`what` 会把命令分析请求组织成结构化 Prompt，减少模型误判：

- `system prompt` 只描述工作方向，例如通用、渗透测试、开发调试或运维排障。
- `user prompt` 包含命令、退出码、结果类型、输出处理方式和原始命令输出。
- 命令输出使用 `text` 代码块包裹，避免和指令混在一起。
- 回答要求会根据结果自动调整：失败时优先给修复命令；有警告时说明是否要处理；`pentest` 模式会要求下一步枚举/验证命令并提醒仅限授权环境。
- `custom_instruction` 只作为用户偏好追加到 `user prompt`，不会污染系统角色。

## 捕获诊断

如果 `what --show` 能看到命令和退出码，但输出是 `(无输出)`，通常表示 `script` 录制日志没有增长。可以先重新打开终端，或执行：

```bash
unset __WHAT_RECORDING
source ~/.what/what-hook.sh
```

新版 hook 会显式通过 `script -c "$SHELL -i"` 启动交互式 shell；主程序也会在检测到 `session.log` 未增长时给出诊断提示。

## 日志

| 文件 | 内容 |
|------|------|
| `~/.what/what.log` | 操作日志：命令读取、API 请求、错误 |
| `~/.what/llm.log` | LLM 对话：完整 prompt 和 response 原文 |
| `~/.what/hook.log` | Shell 钩子：录制启动、命令捕获、退出码 |

```bash
what -d                    # 日志同时打印到屏幕
cat ~/.what/what.log       # 查看完整日志
```

## 卸载

```bash
./install.sh --uninstall
```

## 依赖

- Python 3
- shell: zsh / bash (Linux) 或 PowerShell 5.1+ (Windows)
- `rich`：安装脚本自动装到虚拟环境，用于默认 Markdown 渲染

## 文件布局

```
~/.what/
├── venv/           # Python 虚拟环境
├── what            # Python 主程序
├── what-hook.sh    # Shell 钩子 (Linux)
├── config          # 配置文件
├── what.log        # 操作日志
├── llm.log         # LLM 对话原文
├── hook.log        # 钩子日志
├── session.log     # 终端录制 (Linux)
├── last_cmd        # 上一条命令文本
└── last_exit       # 上一条命令退出码

~/.local/bin/
└── what            # Shell wrapper → 调用 venv 中的 Python

windows/            # Windows PowerShell 支持
├── what-hook.psm1  # PowerShell 钩子模块
├── what.ps1        # PowerShell what 函数
└── install.ps1     # PowerShell 安装脚本
```

## 原理

```
用户执行命令 → shell 钩子捕获(命令/退出码/输出) → 用户输入 what
→ Python 读取捕获数据 → 按配置构建 Prompt → 发给 LLM → Markdown 渲染输出
```

- `what-hook.sh`：用 `script` 录制终端 + zsh `preexec`/`precmd` 或 bash `DEBUG trap` 捕获
- `what`：Python 主程序，调用 LLM 兼容 API
