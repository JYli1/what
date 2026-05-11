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
