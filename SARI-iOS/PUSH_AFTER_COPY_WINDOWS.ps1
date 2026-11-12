$ErrorActionPreference = "Stop"
$git = Get-ChildItem "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $git) {
    throw "GitHub Desktop Git was not found. Open GitHub Desktop at least once, then retry."
}

Write-Host "Using Git: $git"

# The old duplicate resource must not survive when files are copied over an existing repository.
if (Test-Path "SharedResources\data\scholars.json") {
    & $git rm -f -- "SharedResources/data/scholars.json"
}

& $git add -A
& $git status

Write-Host ""
Write-Host "Review the status above. If it looks correct, run:"
Write-Host "& `"$git`" commit -m `"SARI 0.9.2 ultimate iPhone fixes`""
Write-Host "& `"$git`" pull --rebase origin main"
Write-Host "& `"$git`" push origin main"
