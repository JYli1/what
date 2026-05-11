# Windows 支持设计

## 目标

在不影响 Linux 版的前提下，新增 Windows PowerShell 支持。用户执行命令后输入 `what` 即可让 LLM 分析终端输出。

## 约束

- Windows 代码全部放入 `windows/` 子目录，Linux 版文件不动
- Python 主程序改动最小化，仅加平台分支
- 只捕获控制台输出（报错/结果），不依赖 `script` 命令

## 架构

```
┌──────────────────────────────────────────────┐
│                 what.ps1                      │
│  PowerShell 函数入口 → 调用 venv python what   │
├──────────────────────────────────────────────┤
│             what-hook.psm1                    │
│  PSReadLine 钩子 + 输出捕获                    │
│  → 写入 last_cmd / last_exit / output.txt     │
├──────────────────────────────────────────────┤
│                what (Python)                  │
│  主程序：读取捕获数据 → 构建 Prompt → 调 LLM   │
│  改动：get_last_command_info() 加平台分支      │
└──────────────────────────────────────────────┘
```

## 与 Linux 版差异

| | Linux | Windows |
|---|---|---|
| 命令捕获 | bash/zsh trap + `script` | PSReadLine Enter 拦截 |
| 输出捕获 | `script` 录制 → 字节偏移 | Tee-Object → output.txt |
| 退出码 | `$?` | `$LASTEXITCODE` / `$?` |
| 安装 | `install.sh` | `windows/install.ps1` |
| 配置目录 | `~/.what/` | `$env:USERPROFILE\.what\` |
| 入口 | `~/.local/bin/what` bash wrapper | `what` PowerShell 函数 |

## 项目结构

```
what/
├── what                 # Python 主程序（加平台分支）
├── what-hook.sh         # Linux hook（不变）
├── install.sh           # Linux 安装（不变）
├── config.example       # 共享配置（不变）
├── README.md            # 补充 Windows 章节
└── windows/             # ★ 新增
    ├── what-hook.psm1   # PowerShell 钩子模块
    ├── what.ps1         # PowerShell what 函数
    └── install.ps1      # PowerShell 安装脚本
```

## 数据流

```
用户输入命令 → PSReadLine Enter 拦截 → 保存 cmd 文本
     ↓
命令执行（输出同时到终端 + output.txt）
     ↓
Prompt 函数触发 → 保存退出码
     ↓
用户输入 what → what.ps1 → python what → 读取 last_cmd / last_exit / output.txt
     ↓
构建 Prompt → 调 LLM → 渲染输出
```

## 钩子逻辑

```
Enter 按下 → PSReadLine 拦截
  ├─ 空命令 → 正常执行
  ├─ what* → 正常执行，不捕获自身
  └─ 其他 → 保存命令文本，追加 | Tee-Object，执行
            → prompt 函数保存退出码
```

无黑名单，所有命令统一捕获。交互式程序（ssh、vim 等）进入 TUI 后输出不走 stdout 管道，自然不会被截到；连接失败等错误在 stdout 输出，正常捕获。

## 输出捕获策略

- **PowerShell 原生命令**：管道末尾追加 `Tee-Object -FilePath output.txt`，写到文件同时显示
- **原生 exe**（nmap、docker 等）: 用 `cmd /c "… 2>&1"` 包装，合并 stderr→stdout 后捕获
- 统一输出到 `~/.what/output.txt`

## Python 主程序改动

两处：

1. 新增路径常量 `OUTPUT_FILE`（Windows: `output.txt`，Linux: `None`）
2. `get_last_command_info()` 加平台分支：Windows 下直接读 `output.txt`，Linux 保持原有 `session.log` 字节偏移逻辑

其余逻辑（配置、API 调用、Prompt 构建、渲染）全部复用。

## 安装后文件布局

```
$env:USERPROFILE\
├── .what\
│   ├── venv\              # Python 虚拟环境
│   ├── what               # Python 主程序
│   ├── what-hook.psm1     # PowerShell 钩子模块
│   ├── what.ps1           # PowerShell what 函数
│   ├── config             # 配置文件
│   ├── last_cmd           # 上一条命令文本
│   ├── last_exit          # 退出码
│   ├── output.txt         # 捕获的输出
│   ├── what.log           # 操作日志
│   └── llm.log            # LLM 对话原文
└── .local\bin\
    └── what.bat           # CMD 入口
```

## 组件清单

以下是需要新建或修改的文件：

- **新建** `windows/what-hook.psm1` — PSReadLine Enter 拦截 + prompt 钩子 + 输出捕获
- **新建** `windows/what.ps1` — `what` PowerShell 函数，调用 venv python
- **新建** `windows/install.ps1` — PowerShell 安装/卸载脚本
- **修改** `what` — `get_last_command_info()` 加平台分支，新增 `OUTPUT_FILE` 路径
- **修改** `README.md` — 补充 Windows 安装/使用章节
