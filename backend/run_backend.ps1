param(
  [int]$Port = 8000
)

$venv = Join-Path $PSScriptRoot ".venv\Scripts\Activate.ps1"
if (Test-Path $venv) {
  . $venv
} else {
  Write-Host "Creating venv..."
  py -3.11 -m venv (Join-Path $PSScriptRoot ".venv")
  . $venv
  python -m pip install --upgrade pip
}

pip install -r (Join-Path $PSScriptRoot "requirements.txt")
uvicorn main:app --host 0.0.0.0 --port $Port --reload



