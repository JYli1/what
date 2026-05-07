#!/bin/bash
# ──────────────────────────────────────────────────
# what 安装 / 卸载脚本
#   安装: ./install.sh
#   卸载: ./install.sh --uninstall
# ──────────────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.what"
VENV_DIR="$CONFIG_DIR/venv"
WHAT_PY="$CONFIG_DIR/what"

# ═══════════════════════════════════════════════
# 卸载
# ═══════════════════════════════════════════════
if [[ "$1" == "--uninstall" ]]; then
    echo "=============================="
    echo "  what - 卸载"
    echo "=============================="
    echo ""

    # 删除 wrapper
    if [[ -f "$BIN_DIR/what" ]]; then
        rm -f "$BIN_DIR/what"
        echo "[✓] 已删除 $BIN_DIR/what"
    else
        echo "[·] $BIN_DIR/what 不存在，跳过"
    fi

    # 询问是否删除配置目录（含 venv、日志等）
    if [[ -d "$CONFIG_DIR" ]]; then
        echo ""
        echo "目录 $CONFIG_DIR 包含:"
        echo "  - 虚拟环境 (venv/)"
        echo "  - 配置文件 (config)"
        echo "  - 主程序 (what)"
        echo "  - 钩子脚本 (what-hook.sh)"
        echo "  - 会话日志 (session.log)"
        echo ""
        read -p "是否删除整个 $CONFIG_DIR ? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            echo "[✓] 已删除 $CONFIG_DIR"
        else
            echo "[·] 保留 $CONFIG_DIR"
        fi
    fi

    # 从 shell 配置中移除 hook 行
    for RC_FILE in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [[ -f "$RC_FILE" ]]; then
            if grep -q "what-hook.sh" "$RC_FILE" 2>/dev/null; then
                echo ""
                read -p "从 $RC_FILE 中移除 what hook 行? [y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    sed -i.bak '/# what - /d; /what-hook\.sh/d' "$RC_FILE"
                    rm -f "${RC_FILE}.bak"
                    echo "[✓] 已从 $RC_FILE 移除 hook"
                fi
            fi
        fi
    done

    echo ""
    echo "卸载完成。重新打开终端生效。"
    exit 0
fi

# ═══════════════════════════════════════════════
# 安装
# ═══════════════════════════════════════════════
echo "=============================="
echo "  what - 终端命令智能分析工具"
echo "=============================="
echo ""

# ── 创建目录 ──
mkdir -p "$BIN_DIR" "$CONFIG_DIR"

# ── 创建 Python 虚拟环境 ──
echo "--- 创建虚拟环境 ---"
if [[ -d "$VENV_DIR" ]]; then
    echo "[·] 虚拟环境已存在: $VENV_DIR"
else
    python3 -m venv "$VENV_DIR"
    echo "[✓] 虚拟环境已创建: $VENV_DIR"
fi

# ── 安装 Python 依赖 ──
echo ""
echo "--- Python 依赖（可能需要几十秒，视网络而定） ---"
"$VENV_DIR/bin/pip" install rich
echo "[✓] rich 已安装到虚拟环境（Markdown 渲染）"

# ── 安装主程序到 ~/.what/ ──
cp "$SCRIPT_DIR/what" "$WHAT_PY"
chmod +x "$WHAT_PY"
echo "[✓] 主程序: $WHAT_PY"

# ── 创建可执行 wrapper ──
cat > "$BIN_DIR/what" << EOF
#!/bin/bash
exec "$VENV_DIR/bin/python" "$WHAT_PY" "\$@"
EOF
chmod +x "$BIN_DIR/what"
echo "[✓] 可执行文件: $BIN_DIR/what"

# ── 安装 shell 钩子 ──
cp "$SCRIPT_DIR/what-hook.sh" "$CONFIG_DIR/what-hook.sh"
echo "[✓] Shell 钩子: $CONFIG_DIR/what-hook.sh"

# ── 创建配置文件 ──
if [[ ! -f "$CONFIG_DIR/config" ]]; then
    cp "$SCRIPT_DIR/config.example" "$CONFIG_DIR/config"
    echo "[✓] 配置文件: $CONFIG_DIR/config"
else
    echo "[·] 配置文件已存在，跳过"
fi

# ── 检测 shell 并添加 hook ──
SHELL_NAME="$(basename "$SHELL")"
RC_FILE=""

case "$SHELL_NAME" in
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *)
        echo ""
        echo "[!] 未识别的 shell: $SHELL_NAME"
        echo "    请手动添加以下行到你的 shell 配置文件:"
        echo "    source $CONFIG_DIR/what-hook.sh"
        ;;
esac

if [[ -n "$RC_FILE" ]]; then
    HOOK_LINE="source $CONFIG_DIR/what-hook.sh"
    if grep -qF "$HOOK_LINE" "$RC_FILE" 2>/dev/null; then
        echo "[·] Hook 已存在于 $RC_FILE"
    else
        echo "" >> "$RC_FILE"
        echo "# what - 终端命令智能分析工具" >> "$RC_FILE"
        echo "$HOOK_LINE" >> "$RC_FILE"
        echo "[✓] Hook 已添加到 $RC_FILE"
    fi
fi

# ── 检查 PATH ──
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "[!] $BIN_DIR 不在你的 PATH 中"
    echo "    请添加以下行到 $RC_FILE:"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ── 完成 ──
echo ""
echo "=============================="
echo "  安装完成！"
echo "=============================="
echo ""
echo "文件布局:"
echo "  $BIN_DIR/what        → 可执行入口（shell wrapper）"
echo "  $WHAT_PY             → Python 主程序"
echo "  $VENV_DIR/           → Python 虚拟环境"
echo "  $CONFIG_DIR/config   → 配置文件"
echo "  $CONFIG_DIR/what-hook.sh → Shell 钩子"
echo ""
echo "下一步："
echo "  1. 配置 API Key:"
echo "     what --setup"
echo ""
echo "  2. 重新打开终端，或执行:"
echo "     source $RC_FILE"
echo ""
echo "  3. 试试:"
echo "     rustscan -a 10.0.0.1 --json"
echo "     what --md"
echo ""
echo "卸载: ./install.sh --uninstall"
