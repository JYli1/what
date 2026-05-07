# CLAUDE.md — what 项目指南

## 自动维护规则

**修改 `what` 或 `install.sh` 后必须同步更新 `README.md`。** 重点检查：
- 新增/删除/重命名 CLI 参数 → 更新"全部参数"章节的表格
- 安装步骤变化 → 更新安装章节
- 新增日志文件或文件布局变化 → 更新日志/文件布局章节
- 依赖变化 → 更新依赖章节
- 修改完后重新打包 `what.tar.gz`
- **最重要的是**:每次修改操作你需要向我报告你要做什么，直到我说开始操作，你才能操作 

## 项目结构

```
what/               # 这个目录
├── what            # Python 主程序，CLI 入口
├── what-hook.sh    # Shell 钩子 (zsh preexec/precmd + bash DEBUG trap)
├── install.sh      # 安装/卸载脚本
├── config.example  # 配置文件模板
├── README.md       # 用户文档
└── CLAUDE.md       # 本文件
```

## 关键路径 (Linux 目标机)

| 路径 | 用途 |
|------|------|
| `~/.what/venv/` | Python 虚拟环境 |
| `~/.what/what` | 主程序副本 |
| `~/.what/what-hook.sh` | 钩子脚本 |
| `~/.what/config` | 用户配置 |
| `~/.what/what.log` | 操作日志 |
| `~/.what/llm.log` | LLM 完整对话原文 |
| `~/.what/hook.log` | 钩子日志 |
| `~/.what/session.log` | 终端录制 |
| `~/.what/last_cmd` | 上一条命令文本 |
| `~/.what/last_exit` | 上一条命令退出码 |
| `~/.what/output_start` | 输出起始偏移 |
| `~/.what/output_end` | 输出结束偏移 |
| `~/.local/bin/what` | Shell wrapper (调用 venv python) |
