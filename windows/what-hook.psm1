# what-hook.psm1
# PowerShell hook module — captures command text, exit code, and output

$script:WHAT_DIR = "$env:USERPROFILE\.what"
$script:OUTPUT_FILE = "$script:WHAT_DIR\output.txt"
$script:LAST_CMD = "$script:WHAT_DIR\last_cmd"
$script:LAST_EXIT = "$script:WHAT_DIR\last_exit"

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

    # Save original prompt function (use global scope for cross-scope access)
    $global:__WHAT_ORIG_PROMPT = $function:prompt

    # Override prompt to capture exit code after each command
    function global:prompt {
        $lastExit = $global:LASTEXITCODE
        if ($null -ne $lastExit) {
            "$lastExit" | Out-File -FilePath "$env:USERPROFILE\.what\last_exit" -Encoding utf8 -NoNewline
        }
        else {
            $exitCode = if ($?) { "0" } else { "1" }
            $exitCode | Out-File -FilePath "$env:USERPROFILE\.what\last_exit" -Encoding utf8 -NoNewline
        }
        & $global:__WHAT_ORIG_PROMPT
    }

    # PSReadLine Enter key handler
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        $trimmed = $line.Trim()

        # Empty line or what command — execute as-is
        if ([string]::IsNullOrWhiteSpace($line) -or $trimmed -match '^what\b') {
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
            return
        }

        # Save original command text
        $trimmed | Out-File -FilePath "$env:USERPROFILE\.what\last_cmd" -Encoding utf8 -NoNewline

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
    if ($null -ne $global:__WHAT_ORIG_PROMPT) {
        $function:global:prompt = $global:__WHAT_ORIG_PROMPT
        Remove-Variable -Name __WHAT_ORIG_PROMPT -Scope Global -ErrorAction SilentlyContinue
    }

    # Remove Enter key handler (restore default AcceptLine)
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        param($key, $arg)
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

Export-ModuleMember -Function Register-WhatHook, Unregister-WhatHook
