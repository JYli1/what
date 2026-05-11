# --------------------------------------------------
# what install / uninstall script (PowerShell)
#   Install: .\install.ps1
#   Uninstall: .\install.ps1 -Uninstall
# --------------------------------------------------

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJ_DIR = Split-Path -Parent $SCRIPT_DIR

$WHAT_DIR = "$env:USERPROFILE\.what"
$BIN_DIR = "$env:USERPROFILE\.local\bin"
$VENV_DIR = "$WHAT_DIR\venv"

# ==================================================
# Uninstall
# ==================================================
if ($Uninstall) {
    Write-Host "=============================="
    Write-Host "  what - Uninstall"
    Write-Host "=============================="
    Write-Host ""

    # Remove CMD entry point
    $WHAT_BAT = "$BIN_DIR\what.bat"
    if (Test-Path $WHAT_BAT) {
        Remove-Item $WHAT_BAT -Force
        Write-Host "[OK] Removed: $WHAT_BAT"
    } else {
        Write-Host "[.] Not found, skipped: $WHAT_BAT"
    }

    # Ask before deleting config directory (includes venv, logs, etc.)
    if (Test-Path $WHAT_DIR) {
        Write-Host ""
        Write-Host "Directory $WHAT_DIR contains:"
        Write-Host "  - Virtual env (venv\)"
        Write-Host "  - Config file (config)"
        Write-Host "  - Main script (what)"
        Write-Host "  - Hook module (what-hook.psm1)"
        Write-Host "  - Function file (what.ps1)"
        Write-Host "  - Session logs (session.log)"
        Write-Host ""
        $reply = Read-Host "Delete entire $WHAT_DIR ? [y/N]"
        if ($reply -match '^[Yy]$') {
            Remove-Item $WHAT_DIR -Recurse -Force
            Write-Host "[OK] Removed: $WHAT_DIR"
        } else {
            Write-Host "[.] Kept: $WHAT_DIR"
        }
    }

    # Remove what-related lines from $PROFILE
    if (Test-Path $PROFILE) {
        $content = Get-Content $PROFILE -Raw
        if ($content -match 'what-hook\.psm1|what\.ps1|# what -') {
            Write-Host ""
            $reply = Read-Host "Remove what-related lines from $PROFILE ? [y/N]"
            if ($reply -match '^[Yy]$') {
                $lines = Get-Content $PROFILE
                $filtered = @()
                foreach ($line in $lines) {
                    if (($line -notmatch 'what-hook\.psm1') -and
                        ($line -notmatch 'what\.ps1') -and
                        ($line -notmatch '# what -')) {
                        $filtered += $line
                    }
                }
                # Remove trailing blank lines
                while (($filtered.Count -gt 0) -and [string]::IsNullOrWhiteSpace($filtered[-1])) {
                    $filtered = $filtered[0..($filtered.Count - 2)]
                }
                Set-Content -Path $PROFILE -Value $filtered -Encoding UTF8
                Write-Host "[OK] Lines removed from $PROFILE"
            }
        } else {
            Write-Host "[.] No what-related lines found in $PROFILE"
        }
    } else {
        Write-Host "[.] $PROFILE does not exist, skipped"
    }

    Write-Host ""
    Write-Host "Uninstall complete. Restart your PowerShell session."
    exit 0
}

# ==================================================
# Install
# ==================================================
Write-Host "=============================="
Write-Host "  what - Terminal Command Analyzer"
Write-Host "=============================="
Write-Host ""

# Create directories
New-Item -ItemType Directory -Path $BIN_DIR -Force | Out-Null
New-Item -ItemType Directory -Path $WHAT_DIR -Force | Out-Null
Write-Host "[OK] Directory: $BIN_DIR"
Write-Host "[OK] Directory: $WHAT_DIR"

# Create Python virtual environment
Write-Host ""
Write-Host "--- Creating virtual environment ---"
if (Test-Path $VENV_DIR) {
    Write-Host "[.] Virtual env already exists: $VENV_DIR"
} else {
    & python -m venv $VENV_DIR
    Write-Host "[OK] Virtual env created: $VENV_DIR"
}

# Install Python dependencies
Write-Host ""
Write-Host "--- Python dependencies (may take a while) ---"
$pip = "$VENV_DIR\Scripts\pip.exe"
& $pip install rich
Write-Host "[OK] rich installed to virtual env (Markdown rendering)"

# Install main script to ~/.what/
Copy-Item "$PROJ_DIR\what" "$WHAT_DIR\what" -Force
Write-Host "[OK] Main script: $WHAT_DIR\what"

# Install hook module
Copy-Item "$SCRIPT_DIR\what-hook.psm1" "$WHAT_DIR\what-hook.psm1" -Force
Write-Host "[OK] Hook module: $WHAT_DIR\what-hook.psm1"

# Install what.ps1
Copy-Item "$SCRIPT_DIR\what.ps1" "$WHAT_DIR\what.ps1" -Force
Write-Host "[OK] Function file: $WHAT_DIR\what.ps1"

# Create config file
if (-not (Test-Path "$WHAT_DIR\config")) {
    Copy-Item "$PROJ_DIR\config.example" "$WHAT_DIR\config" -Force
    Write-Host "[OK] Config file: $WHAT_DIR\config"
} else {
    Write-Host "[.] Config file already exists, skipped"
}

# Create CMD entry point
$WHAT_BAT = "$BIN_DIR\what.bat"
$batLine = '@"' + '%USERPROFILE%\.what\venv\Scripts\python.exe" "' + '%USERPROFILE%\.what\what" %*'
Set-Content -Path $WHAT_BAT -Value $batLine -Encoding ASCII
Write-Host "[OK] CMD entry point: $WHAT_BAT"

# Check PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
$machinePath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$combinedPath = "$userPath;$machinePath"
$pathEntries = $combinedPath -split ';'
$binInPath = $false
foreach ($entry in $pathEntries) {
    if ($entry.TrimEnd('\') -eq $BIN_DIR.TrimEnd('\')) {
        $binInPath = $true
        break
    }
}
if (-not $binInPath) {
    Write-Host ""
    Write-Host "[WARN] $BIN_DIR is NOT in your PATH"
    Write-Host "       Add it to system environment variables, or add to $PROFILE :"
    Write-Host '       $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"'
}

# Add hook to $PROFILE
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$hookLine1 = '# what - terminal command analysis tool'
$hookLine2 = 'Import-Module "$env:USERPROFILE\.what\what-hook.psm1" -Force; Register-WhatHook'
$hookLine3 = '. "$env:USERPROFILE\.what\what.ps1"'

if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE -Raw
    if ($profileContent -match 'what-hook\.psm1') {
        Write-Host "[.] Hook already present in $PROFILE"
    } else {
        Add-Content -Path $PROFILE -Value "" -Encoding UTF8
        Add-Content -Path $PROFILE -Value $hookLine1 -Encoding UTF8
        Add-Content -Path $PROFILE -Value $hookLine2 -Encoding UTF8
        Add-Content -Path $PROFILE -Value $hookLine3 -Encoding UTF8
        Write-Host "[OK] Hook added to $PROFILE"
    }
} else {
    Set-Content -Path $PROFILE -Value @($hookLine1, $hookLine2, $hookLine3) -Encoding UTF8
    Write-Host "[OK] $PROFILE created with hook"
}

# Done
Write-Host ""
Write-Host "=============================="
Write-Host "  Install complete!"
Write-Host "=============================="
Write-Host ""
Write-Host "File layout:"
Write-Host "  $BIN_DIR\what.bat          -> CMD entry point"
Write-Host "  $WHAT_DIR\what             -> Python main script"
Write-Host "  $VENV_DIR\                 -> Python virtual env"
Write-Host "  $WHAT_DIR\config           -> Config file"
Write-Host "  $WHAT_DIR\what-hook.psm1   -> PowerShell hook module"
Write-Host "  $WHAT_DIR\what.ps1         -> PowerShell what function"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Configure API key:"
Write-Host "     what --setup"
Write-Host ""
Write-Host "  2. Restart PowerShell, or run:"
Write-Host "     . `$PROFILE"
Write-Host ""
Write-Host "  3. Try it out:"
Write-Host "     rustscan -a 10.0.0.1 --json"
Write-Host "     what --md"
Write-Host ""
Write-Host "Uninstall: .\install.ps1 -Uninstall"
