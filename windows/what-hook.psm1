# what-hook.psm1
# PowerShell hook module — captures command text, exit code, and output
# Uses Start-Transcript for background recording (like Linux `script`)

$script:WHAT_DIR = "$env:USERPROFILE\.what"
$script:TRANSCRIPT_FILE = "$script:WHAT_DIR\transcript.txt"
$script:LAST_CMD = "$script:WHAT_DIR\last_cmd"
$script:LAST_EXIT = "$script:WHAT_DIR\last_exit"
$script:OUTPUT_START = "$script:WHAT_DIR\output_start"
$script:OUTPUT_END = "$script:WHAT_DIR\output_end"

function Register-WhatHook {
    if (-not (Test-Path $script:WHAT_DIR)) {
        New-Item -ItemType Directory -Path $script:WHAT_DIR -Force | Out-Null
    }

    # Start background transcript recording
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
    Start-Transcript -Path $script:TRANSCRIPT_FILE -Append | Out-Null

    # Save original prompt function
    $global:__WHAT_ORIG_PROMPT = $function:prompt

    # Override prompt to capture exit code and output end position
    function global:prompt {
        $lastExit = $global:LASTEXITCODE
        if ($null -ne $lastExit) {
            "$lastExit" | Out-File -FilePath $script:LAST_EXIT -Encoding utf8 -NoNewline
        }
        else {
            $exitCode = if ($?) { "0" } else { "1" }
            $exitCode | Out-File -FilePath $script:LAST_EXIT -Encoding utf8 -NoNewline
        }

        # Record output end position
        if (Test-Path $script:TRANSCRIPT_FILE) {
            (Get-Item $script:TRANSCRIPT_FILE).Length | Out-File -FilePath $script:OUTPUT_END -Encoding utf8 -NoNewline
        }

        & $global:__WHAT_ORIG_PROMPT
    }

    # PSReadLine Enter key handler — save command text and output start position
    # Does NOT modify the command line (user sees original command)
    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        param($key, $arg)

        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        $trimmed = $line.Trim()

        if (-not [string]::IsNullOrWhiteSpace($line) -and $trimmed -notmatch '^what\b') {
            # Save original command text
            $trimmed | Out-File -FilePath $script:LAST_CMD -Encoding utf8 -NoNewline

            # Record output start position (before command executes)
            if (Test-Path $script:TRANSCRIPT_FILE) {
                (Get-Item $script:TRANSCRIPT_FILE).Length | Out-File -FilePath $script:OUTPUT_START -Encoding utf8 -NoNewline
            }
        }

        # Execute as-is — no wrapper, user sees their original command
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

function Unregister-WhatHook {
    if ($null -ne $global:__WHAT_ORIG_PROMPT) {
        $function:global:prompt = $global:__WHAT_ORIG_PROMPT
        Remove-Variable -Name __WHAT_ORIG_PROMPT -Scope Global -ErrorAction SilentlyContinue
    }

    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}

    Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
        param($key, $arg)
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}

Export-ModuleMember -Function Register-WhatHook, Unregister-WhatHook
