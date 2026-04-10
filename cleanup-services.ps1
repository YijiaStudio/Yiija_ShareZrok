param(
  [Parameter(Mandatory = $true)][string]$RepoRoot,
  [Parameter(Mandatory = $true)][string]$OldManagedFile,
  [Parameter(Mandatory = $true)][string]$NewManagedFile,
  [Parameter(Mandatory = $true)][string]$RemovedOutFile
)

$ErrorActionPreference = 'Stop'

function Read-Set([string]$path) {
  $set = @{}
  if (Test-Path -LiteralPath $path) {
    Get-Content -LiteralPath $path | ForEach-Object {
      $v = $_.Trim()
      if ($v) { $set[$v] = $true }
    }
  }
  return $set
}

$old = Read-Set $OldManagedFile
$new = Read-Set $NewManagedFile
$removed = @()

foreach ($name in $old.Keys) {
  if (-not $new.ContainsKey($name)) {
    $dir = Join-Path $RepoRoot $name
    if (Test-Path -LiteralPath $dir) {
      Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $removed += $name
  }
}

[System.IO.File]::WriteAllLines($RemovedOutFile, $removed, [System.Text.UTF8Encoding]::new($false))
