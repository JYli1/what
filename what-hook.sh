#!/bin/bash
# ──────────────────────────────────────────────────────────
# what-hook.sh - what 命令的 shell 集成脚本
# 将以下行添加到你的 .zshrc 或 .bashrc 中:
#   source ~/.what/what-hook.sh
# ──────────────────────────────────────────────────────────

__WHAT_DIR="$HOME/.what"
__WHAT_SESSION_LOG="$__WHAT_DIR/session.log"
__WHAT_LOG="$__WHAT_DIR/hook.log"

# ── 简易日志 ──
__what_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$__WHAT_LOG" 2>/dev/null || true
}

# ── 确保目录存在 ──
mkdir -p "$__WHAT_DIR"

# ══════════════════════════════════════════════════════════
# 阶段 1: 如果尚未录制，启动 script 会话录制
# ══════════════════════════════════════════════════════════
if [[ -z "$__WHAT_RECORDING" && "$TERM" != "dumb" && -z "$INSIDE_EMACS" ]]; then
    export __WHAT_RECORDING=1
    : > "$__WHAT_SESSION_LOG"
    __what_log "启动 session 录制"
    exec script -q -f "$__WHAT_SESSION_LOG" -c "${SHELL:-/bin/sh} -i"
fi
__what_log "录制模式已激活"

# ══════════════════════════════════════════════════════════
# 阶段 2: 在录制会话中，设置命令捕获钩子
# ══════════════════════════════════════════════════════════
if [[ -n "$__WHAT_RECORDING" ]]; then

    # ── 标志：是否需要在 precmd/PROMPT_COMMAND 中记录 ──
    typeset -g __WHAT_SHOULD_RECORD=0

    # ────────────────────────────────────────────────────
    # ZSH 钩子
    # ────────────────────────────────────────────────────
    if [[ -n "$ZSH_VERSION" ]]; then

        __what_preexec() {
            if [[ "$1" == "what" || "$1" == what\ * ]]; then
                __WHAT_SHOULD_RECORD=0
                return
            fi
            __WHAT_SHOULD_RECORD=1
            echo "$1" > "$__WHAT_DIR/last_cmd"
            stat -c %s "$__WHAT_SESSION_LOG" > "$__WHAT_DIR/output_start" 2>/dev/null \
                || echo 0 > "$__WHAT_DIR/output_start"
            __what_log "preexec: $1"
        }

        __what_precmd() {
            local last_exit=$?
            if (( __WHAT_SHOULD_RECORD )); then
                echo "$last_exit" > "$__WHAT_DIR/last_exit"
                stat -c %s "$__WHAT_SESSION_LOG" > "$__WHAT_DIR/output_end" 2>/dev/null \
                    || echo 0 > "$__WHAT_DIR/output_end"
                __what_log "precmd: exit=$last_exit"
                __WHAT_SHOULD_RECORD=0
            fi
        }

        autoload -Uz add-zsh-hook
        add-zsh-hook preexec __what_preexec
        add-zsh-hook precmd __what_precmd

    # ────────────────────────────────────────────────────
    # BASH 钩子
    # ────────────────────────────────────────────────────
    elif [[ -n "$BASH_VERSION" ]]; then

        # 使用 DEBUG trap 模拟 preexec
        __WHAT_BASH_TRAPPED=0

        __what_debug_trap() {
            local cmd="$BASH_COMMAND"

            [[ "$cmd" == *__what_* ]] && return
            [[ "$cmd" == "what" || "$cmd" == what\ * ]] && { __WHAT_SHOULD_RECORD=0; __WHAT_BASH_TRAPPED=0; return; }

            if (( ! __WHAT_BASH_TRAPPED )); then
                __WHAT_BASH_TRAPPED=1
                __WHAT_SHOULD_RECORD=1
                echo "$cmd" > "$__WHAT_DIR/last_cmd"
                stat -c %s "$__WHAT_SESSION_LOG" > "$__WHAT_DIR/output_start" 2>/dev/null \
                    || echo 0 > "$__WHAT_DIR/output_start"
                __what_log "preexec: $cmd"
            fi
        }

        __what_prompt_command() {
            local last_exit=$?
            if (( __WHAT_SHOULD_RECORD )); then
                echo "$last_exit" > "$__WHAT_DIR/last_exit"
                stat -c %s "$__WHAT_SESSION_LOG" > "$__WHAT_DIR/output_end" 2>/dev/null \
                    || echo 0 > "$__WHAT_DIR/output_end"
                __what_log "precmd: exit=$last_exit"
                __WHAT_SHOULD_RECORD=0
            fi
            __WHAT_BASH_TRAPPED=0
        }

        trap '__what_debug_trap' DEBUG
        PROMPT_COMMAND="__what_prompt_command${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
    fi
fi
