# Windows PowerShell Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Windows PowerShell support to `what` with minimal impact on existing Linux code.

**Architecture:** New `windows/` subdirectory with PowerShell hook module (PSReadLine Enter interception + output Tee), a `what` function entry, and an install script. Python main script gets a single platform branch in `get_last_command_info()`.

**Tech Stack:** PowerShell 5.1+, PSReadLine, Python 3, venv

---

### Task 1: Create `windows/what-hook.psm1` — PowerShell Hook Module

**Files:**
- Create: `windows/what-hook.psm1`

- [ ] **Step 1: Write the module with all functions**

```powershell
# what-hook.psm1
# PowerShell hook module — captures command text, exit code, and output

$script:WHAT_DIR = "$env:USERPROFILE\.what"
$script:OUTPUT_FILE = "$script:WHAT_DIR\output.txt"
$script:LAST_CMD = "$script:WHAT_DIR\last_cmd"
$script:LAST_EXIT = "$script:WHAT_DIR\last_exit"

$script:origPrompt = $null

function Build-WhatWrapper {
    param([string]$Command)
    $outFile = $script:OUTPUT_FILE
    return "Clear-Content '$outFile' -ErrorAction SilentlyContinue; & { $Command } *>&1 | Tee-Object -FilePath '$outFile'"
}

function Register-WhatHook {
    # Ensure data directory exists
    if (-not (Test-Path $script:WHAT_DIR)) {
        New-Item -ItemType Directory -Path $script:WHAT_DIR -Force | Out-Null
    }

    # Save original prompt function
    $script:origPrompt = $function:prompt

    # Override prompt to capture exit code after each command
    function global:prompt {
        $lastExit = $global:LASTEXITCODE
        if ($null -ne $lastExit) {
            "$lastExit" | Out-File -FilePath $script:LAST_EXIT -Encoding utf8 -NoNewline
        }
        else {
            if ($?) { "0" } else { "1" } | Out-File -FilePath $script:LAST_EXIT -Encoding utf8 -NoNewline
        }
        & $script:origPrompt
    }

    # PSReadLine Enter key handler — capture command text and wrap for output capture
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        $trimmed = $line.Trim()

        # Empty line or what command — execute as-is, no capture
        if ([string]::IsNullOrWhiteSpace($line) -or $trimmed -match '^what\b') {
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            return
        }

        # Save original command text
        $trimmed | Out-File -FilePath $script:LAST_CMD -Encoding utf8 -NoNewline

        # Build wrapped command that tees output to file
        $wrapped = Build-WhatWrapper -Command $trimmed

        # Replace line with wrapped version and submit
        [Microsoft.PowerShell.PSConsoleReadLine]::BeginUndoGroup()
        [Microsoft.PowerShell.PSConsoleReadLine]::DeleteLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($wrapped)
        [Microsoft.PowerShell.PSConsoleReadLine]::EndUndoGroup()
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

function Unregister-WhatHook {
    # Restore original prompt
    if ($null -ne $script:origPrompt) {
        $function:global:prompt = $script:origPrompt
    }

    # Remove Enter key handler (restore default)
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        param($key, $arg)
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

Export-ModuleMember -Function Register-WhatHook, Unregister-WhatHook
```

- [ ] **Step 2: Verify the module loads without syntax errors**

Run:
```powershell
powershell -NoProfile -Command "Import-Module D:\github_project\what\windows\what-hook.psm1 -Force; Write-Host 'OK'"
```
Expected: `OK`

---

### Task 2: Create `windows/what.ps1` — PowerShell what Function

**Files:**
- Create: `windows/what.ps1`

- [ ] **Step 1: Write the function file**

```powershell
# what.ps1
# PowerShell what function — calls the Python main script through venv

function what {
    $WHAT_DIR = "$env:USERPROFILE\.what"
    $VENV_PY  = "$WHAT_DIR\venv\Scripts\python.exe"
    $MAIN     = "$WHAT_DIR\what"

    if (-not (Test-Path $VENV_PY)) {
        Write-Error "what: Python venv not found at $VENV_PY. Please run install.ps1 first."
        return 1
    }

    & $VENV_PY $MAIN @args
}
```

- [ ] **Step 2: Verify syntax**

Run:
```powershell
powershell -NoProfile -Command ". D:\github_project\what\windows\what.ps1; Get-Command what"
```
Expected: CommandType Function, Name what

---

### Task 3: Create `windows/install.ps1` — PowerShell Install Script

**Files:**
- Create: `windows/install.ps1`

- [ ] **Step 1: Write the install script**

```powershell
# install.ps1
# what Windows install / uninstall script
#   Install: .\install.ps1
#   Uninstall: .\install.ps1 -Uninstall

param([switch]$Uninstall)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJ_DIR   = Split-Path -Parent $SCRIPT_DIR  # project root
$WHAT_DIR   = "$env:USERPROFILE\.what"
$VENV_DIR   = "$WHAT_DIR\venv"
$BIN_DIR    = "$env:USERPROFILE\.local\bin"

# ═══════════════════════════════════════════════
# Uninstall
# ═══════════════════════════════════════════════
if ($Uninstall) {
    Write-Host "=============================="
    Write-Host "  what - Uninstall (Windows)"
    Write-Host "=============================="
    Write-Host ""

    if (Test-Path "$BIN_DIR\what.bat") {
        Remove-Item "$BIN_DIR\what.bat" -Force
        Write-Host "[OK] Removed $BIN_DIR\what.bat"
    } else {
        Write-Host "[.] $BIN_DIR\what.bat not found, skipping"
    }

    if (Test-Path $WHAT_DIR) {
        Write-Host ""
        Write-Host "Directory $WHAT_DIR contains:"
        Write-Host "  - venv\"
        Write-Host "  - config"
        Write-Host "  - what (Python script)"
        Write-Host "  - what-hook.psm1"
        Write-Host "  - what.ps1"
        Write-Host "  - session.log / output.txt"
        Write-Host ""
        $answer = Read-Host "Delete entire $WHAT_DIR ? [y/N]"
        if ($answer -eq 'y' -or $answer -eq 'Y') {
            Remove-Item $WHAT_DIR -Recurse -Force
            Write-Host "[OK] Removed $WHAT_DIR"
        } else {
            Write-Host "[.] Kept $WHAT_DIR"
        }
    }

    # Remove from $PROFILE
    if (Test-Path $PROFILE) {
        $content = Get-Content $PROFILE -Raw
        if ($content -match 'what\.ps1') {
            Write-Host ""
            $answer = Read-Host "Remove what lines from PowerShell profile? [y/N]"
            if ($answer -eq 'y' -or $answer -eq 'Y') {
                $lines = Get-Content $PROFILE | Where-Object { $_ -notmatch 'what(-hook|\.ps1|\.psm1)' }
                $lines | Set-Content $PROFILE
                Write-Host "[OK] Removed what lines from profile"
            }
        }
    }

    Write-Host ""
    Write-Host "Uninstall complete. Close and reopen PowerShell for changes to take effect."
    exit 0
}

# ═══════════════════════════════════════════════
# Install
# ═══════════════════════════════════════════════
Write-Host "=============================="
Write-Host "  what - Terminal Command Analyzer (Windows)"
Write-Host "=============================="
Write-Host ""

# 1. Create directories
New-Item -ItemType Directory -Path $BIN_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $WHAT_DIR -Force | Out-Null
Write-Host "[OK] Directories created"

# 2. Create Python venv
Write-Host ""
Write-Host "--- Creating Python virtual environment ---"
if (Test-Path $VENV_DIR) {
    Write-Host "[.] venv already exists: $VENV_DIR"
} else {
    python -m venv $VENV_DIR
    Write-Host "[OK] venv created: $VENV_DIR"
}

# 3. Install Python dependencies
Write-Host ""
Write-Host "--- Installing Python dependencies ---"
& "$VENV_DIR\Scripts\pip.exe" install rich
Write-Host "[OK] rich installed (Markdown rendering)"

# 4. Copy main program
Copy-Item "$PROJ_DIR\what" "$WHAT_DIR\what" -Force
Write-Host "[OK] Main program: $WHAT_DIR\what"

# 5. Copy hook module
Copy-Item "$SCRIPT_DIR\what-hook.psm1" "$WHAT_DIR\what-hook.psm1" -Force
Write-Host "[OK] Hook module: $WHAT_DIR\what-hook.psm1"

# 6. Copy what function
Copy-Item "$SCRIPT_DIR\what.ps1" "$WHAT_DIR\what.ps1" -Force
Write-Host "[OK] what function: $WHAT_DIR\what.ps1"

# 7. Create config if not exists
if (-not (Test-Path "$WHAT_DIR\config")) {
    Copy-Item "$PROJ_DIR\config.example" "$WHAT_DIR\config"
    Write-Host "[OK] Config: $WHAT_DIR\config"
} else {
    Write-Host "[.] Config already exists, skipping"
}

# 8. Create CMD entry point
@"
@echo off
"$VENV_DIR\Scripts\python.exe" "$WHAT_DIR\what" %*
"@ | Out-File -FilePath "$BIN_DIR\what.bat" -Encoding ascii
Write-Host "[OK] CMD entry: $BIN_DIR\what.bat"

# 9. Check PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$BIN_DIR*") {
    Write-Host ""
    Write-Host "[!] $BIN_DIR is not in your PATH"
    Write-Host "    Run this to add it:"
    Write-Host '    [Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";' + "$BIN_DIR" + '", "User")'
}

# 10. Add hook to PowerShell profile
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
$hookLine = 'Import-Module "$env:USERPROFILE\.what\what-hook.psm1" -Force; Register-WhatHook'
$funcLine = '. "$env:USERPROFILE\.what\what.ps1"'

if ($profileContent -notmatch 'what-hook\.psm1') {
    Add-Content $PROFILE ""
    Add-Content $PROFILE "# what - terminal command analyzer"
    Add-Content $PROFILE $hookLine
    Write-Host "[OK] Hook added to PowerShell profile"
} else {
    Write-Host "[.] Hook already in PowerShell profile"
}

if ($profileContent -notmatch 'what\.ps1') {
    Add-Content $PROFILE $funcLine
    Write-Host "[OK] what function added to PowerShell profile"
} else {
    Write-Host "[.] what function already in PowerShell profile"
}

# 11. Done
Write-Host ""
Write-Host "=============================="
Write-Host "  Install complete!"
Write-Host "=============================="
Write-Host ""
Write-Host "File layout:"
Write-Host "  $BIN_DIR\what.bat         -> CMD entry"
Write-Host "  $WHAT_DIR\what             -> Python main program"
Write-Host "  $WHAT_DIR\what-hook.psm1   -> PowerShell hook"
Write-Host "  $WHAT_DIR\what.ps1         -> PowerShell what function"
Write-Host "  $WHAT_DIR\config           -> Configuration"
Write-Host "  $VENV_DIR\                 -> Python venv"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Configure API Key:"
Write-Host "     what --setup"
Write-Host ""
Write-Host "  2. Restart PowerShell, or run:"
Write-Host "     . `$PROFILE"
Write-Host ""
Write-Host "  3. Try it:"
Write-Host "     dir"
Write-Host "     what"
Write-Host ""
Write-Host "Uninstall: .\install.ps1 -Uninstall"
```

- [ ] **Step 2: Verify install script syntax**

Run:
```powershell
powershell -NoProfile -Command "
$ErrorActionPreference = 'Stop'
try {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile('D:\github_project\what\windows\install.ps1', [ref]$null, [ref]$null)
    if ($ast) { Write-Host 'Syntax OK' }
} catch {
    Write-Host 'Syntax ERROR:' $_.Exception.Message
}
"
```
Expected: `Syntax OK`

---

### Task 4: Modify `what` Python Script — Platform Branch

**Files:**
- Modify: `what`

- [ ] **Step 1: Add `OUTPUT_FILE` path constant**

After line 24 (`LOG_MAX_BYTES = ...`), add:

```python
import platform
IS_WINDOWS = platform.system() == "Windows"
if IS_WINDOWS:
    OUTPUT_FILE = os.path.join(CONFIG_DIR, "output.txt")
else:
    OUTPUT_FILE = None
```

- [ ] **Step 2: Modify `get_last_command_info()` to handle Windows**

Replace the output-reading logic (lines 168-210) with a platform branch. The function becomes:

```python
def get_last_command_info():
    """读取上一条命令、退出码和输出"""
    cmd = read_file(LAST_CMD_FILE)
    exit_code = read_file(LAST_EXIT_FILE) or "unknown"

    log(f"读取命令: cmd={cmd[:200] if cmd else '(空)'}, exit={exit_code}")

    if IS_WINDOWS:
        output = read_file(OUTPUT_FILE)
        log(f"读取输出 (Windows): {len(output)} 字符")
    else:
        output = ""
        start_str = read_file(OUTPUT_START_FILE)
        end_str = read_file(OUTPUT_END_FILE)

        if start_str and end_str:
            try:
                start = int(start_str)
                end = int(end_str)
                if os.path.exists(SESSION_LOG) and end > start:
                    with open(SESSION_LOG, "rb") as f:
                        f.seek(start)
                        raw = f.read(end - start)
                    output = strip_ansi(raw.decode("utf-8", errors="replace"))
                    output = output.strip()
                    log(f"读取输出: {len(output)} 字符 (offset {start}-{end})")
                elif os.path.exists(SESSION_LOG) and end == start:
                    session_size = os.path.getsize(SESSION_LOG)
                    if session_size <= start:
                        output = (
                            "[what 诊断] session.log 未增长，未捕获到命令输出。\n"
                            "请重新打开终端，或执行: unset __WHAT_RECORDING; source ~/.what/what-hook.sh"
                        )
                        log(
                            f"session.log 未增长: start={start}, end={end}, size={session_size}",
                            "WARN",
                        )
                    else:
                        with open(SESSION_LOG, "rb") as f:
                            f.seek(start)
                            raw = f.read(session_size - start)
                        output = strip_ansi(raw.decode("utf-8", errors="replace")).strip()
                        log(
                            f"output_end 未更新，回退读取到文件末尾: {len(output)} 字符 "
                            f"(offset {start}-{session_size})",
                            "WARN",
                        )
                else:
                    log(f"session.log 不可用: start={start_str}, end={end_str}", "WARN")
            except (ValueError, IOError, OSError) as e:
                log(f"读取输出异常: {e}", "ERROR")
        else:
            log(f"output_start/end 为空: start={start_str}, end={end_str}", "WARN")

    if not cmd:
        log("命令为空 — hook 可能未加载", "WARN")

    return cmd, exit_code, output
```

- [ ] **Step 3: Verify Python syntax**

Run:
```bash
python -c "import py_compile; py_compile.compile('D:/github_project/what/what', doraise=True); print('Syntax OK')"
```
Expected: `Syntax OK`

---

### Task 5: Update `README.md` — Add Windows Section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the introduction to mention Windows support**

In the opening paragraph, change:
```
`what` 是一个终端命令智能分析工具
```
to:
```
`what` 是一个终端命令智能分析工具（支持 Linux / Windows PowerShell）
```

- [ ] **Step 2: Update shell requirement**

Change:
```
- shell: zsh 或 bash
```
to:
```
- shell: zsh / bash (Linux) 或 PowerShell 5.1+ (Windows)
```

- [ ] **Step 3: Add Windows installation section after the Linux install section**

After the existing "安装" section, add:

```markdown
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
```

- [ ] **Step 4: Update file layout to include Windows files**

Add to the file layout tree:

```markdown
windows/
├── what-hook.psm1   # PowerShell 钩子
├── what.ps1         # PowerShell what 函数
└── install.ps1      # PowerShell 安装脚本
```

---

### Task 6: Final Verification

- [ ] **Step 1: Verify all files exist and are syntactically valid**

Run:
```bash
echo "=== Checking file structure ===" && ls -la windows/ && echo "" && echo "=== Python syntax ===" && python -c "import py_compile; py_compile.compile('what', doraise=True); print('OK')" && echo "" && echo "=== PowerShell syntax ===" && powershell -NoProfile -Command "& { $ErrorActionPreference='Stop'; [System.Management.Automation.Language.Parser]::ParseFile('windows/what-hook.psm1', [ref]$null, [ref]$null); Write-Host 'what-hook.psm1 OK'; [System.Management.Automation.Language.Parser]::ParseFile('windows/what.ps1', [ref]$null, [ref]$null); Write-Host 'what.ps1 OK'; [System.Management.Automation.Language.Parser]::ParseFile('windows/install.ps1', [ref]$null, [ref]$null); Write-Host 'install.ps1 OK' }"
```
Expected: All files OK
