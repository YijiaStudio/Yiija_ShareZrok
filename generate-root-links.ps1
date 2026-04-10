param(
  [Parameter(Mandatory = $true)][string]$NodesDir,
  [Parameter(Mandatory = $true)][string]$OutFile
)

$ErrorActionPreference = 'Stop'

$items = @()
if (Test-Path -LiteralPath $NodesDir) {
  Get-ChildItem -LiteralPath $NodesDir -Directory | ForEach-Object {
    $node = $_.Name
    $f = Join-Path $_.FullName 'share_urls.txt'
    if (-not (Test-Path -LiteralPath $f)) { return }
    Get-Content -LiteralPath $f | ForEach-Object {
      $line = $_.Trim()
      if (-not $line) { return }
      $parts = $line.Split('|', 2)
      if ($parts.Count -lt 2) { return }
      $name = $parts[0].Trim()
      $url = $parts[1].Trim()
      if (-not $name -or -not $url) { return }
      $items += [pscustomobject]@{
        Label = "$name ($node)"
        Url   = $url
      }
    }
  }
}

$links = if ($items.Count -gt 0) {
  ($items | ForEach-Object { "    <a class=""item"" href=""$($_.Url)"">$($_.Label)</a>" }) -join "`r`n"
} else {
  "    <div class=""empty"">No online services</div>"
}

$html = @"
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
  <meta http-equiv="Pragma" content="no-cache" />
  <meta http-equiv="Expires" content="0" />
  <title>Yiija Share Zrok</title>
  <style>
    body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial;max-width:980px;margin:40px auto;padding:0 16px}
    h1{font-size:22px;margin:0 0 14px}
    .list{display:flex;gap:8px;flex-wrap:wrap}
    a.item{border:1px solid #ddd;background:#fff;border-radius:10px;padding:8px 12px;text-decoration:none;color:#111;font-weight:700}
    a.item:hover{border-color:#0057ff;color:#0057ff}
    .empty{color:#666}
  </style>
</head>
<body>
  <h1>Yiija Share Zrok</h1>
  <div class="list">
$links
  </div>
</body>
</html>
"@

[System.IO.File]::WriteAllText($OutFile, $html, [System.Text.UTF8Encoding]::new($false))
