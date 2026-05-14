# what-hook.psm1
# PowerShell hook module — captures command text and exit code.
# Output is captured by the Python side via re-execution.

$script:WHAT_DIR = "$env:USERPROFILE\.what"
$script:LAST_CMD = "$script:WHAT_DIR\last_cmd"
$script:LAST_EXIT = "$script:WHAT_DIR\last_exit"

function Register-WhatHook {
    if (-not (Test-Path $script:WHAT_DIR)) {
        New-Item -ItemType Directory -Path $script:WHAT_DIR -Force | Out-Null
    }

    $global:__WHAT_LAST_CMD = $script:LAST_CMD
    $global:__WHAT_LAST_EXIT = $script:LAST_EXIT

    # Save original prompt
    $global:__WHAT_ORIG_PROMPT = $function:prompt

    # Override prompt — captures exit code and command from history
    function global:prompt {
        $success = $?
        $lastExit = $global:LASTEXITCODE

        if ($success) {
            $exitCode = if ($null -ne $lastExit -and $lastExit -ne 0) { "$lastExit" } else { "0" }
        } else {
            $exitCode = if ($null -ne $lastExit -and $lastExit -ne 0) { "$lastExit" } else { "1" }
        }
        [System.IO.File]::WriteAllText($global:__WHAT_LAST_EXIT, $exitCode)

        # Save last command from history
        $lastHist = Get-History -Count 1
        if ($null -ne $lastHist) {
            $cmdLine = $lastHist.CommandLine.Trim()
            if ($cmdLine -notmatch '^what\b') {
                [System.IO.File]::WriteAllText($global:__WHAT_LAST_CMD, $cmdLine)
            }
        }

        & $global:__WHAT_ORIG_PROMPT
    }
}

function Unregister-WhatHook {
    if ($null -ne $global:__WHAT_ORIG_PROMPT) {
        $function:global:prompt = $global:__WHAT_ORIG_PROMPT
        Remove-Variable -Name __WHAT_ORIG_PROMPT -Scope Global -ErrorAction SilentlyContinue
    }

    Remove-Variable -Name __WHAT_LAST_CMD, __WHAT_LAST_EXIT -Scope Global -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Register-WhatHook, Unregister-WhatHook
