param(
  [Parameter(Mandatory = $true)][string]$ServicesFile,
  [Parameter(Mandatory = $true)][string]$ShareUrlsFile,
  [Parameter(Mandatory = $true)][string]$OutFile
)

$ErrorActionPreference = 'Stop'

function Get-SafeName([string]$name) {
  $n = $name
  if ($null -eq $n) { $n = '' }
  $n = $n.Trim()
  if (-not $n) { return 'service' }
  $n = $n -replace ' ', '_'
  $safe = [regex]::Replace($n, '[^A-Za-z0-9_-]', '_')
  if (-not $safe) { return 'service' }
  return $safe
}

# Read desired order from services.txt (name|url or url-only)
$names = @()
$idx = 1
Get-Content -LiteralPath $ServicesFile | ForEach-Object {
  $line = $_.Trim()
  if (-not $line -or $line.StartsWith('#')) { return }
  if ($line.Contains('|')) {
    $parts = $line.Split('|', 2)
    $n = $parts[0].Trim()
    if (-not $n) { $n = "service$idx" }
    $names += $n
  } else {
    $names += "service$idx"
  }
  $idx++
}

# Read current urls from share_urls.txt: Name|https://...
$urlMap = @{}
Get-Content -LiteralPath $ShareUrlsFile | ForEach-Object {
  $l = $_.Trim()
  if (-not $l) { return }
  $p = $l.Split('|', 2)
  if ($p.Count -lt 2) { return }
  $urlMap[$p[0].Trim()] = $p[1].Trim()
}

$tabs = foreach ($n in $names) {
  $safe = Get-SafeName $n
  $u = $urlMap[$n]
  if (-not $u) { $u = '' }
  [pscustomobject]@{ name = $n; safe = $safe; url = $u }
}

$tabLinks = foreach ($t in $tabs) {
  $href = $t.url
  if (-not $href) { $href = "./$($t.safe)/" }
  "<a class=""tab"" href=""$href"" data-name=""$($t.name)"" data-safe=""$($t.safe)"">$($t.name)</a>"
}

$linksHtml = ($tabLinks -join "`r`n    ")

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
    .tabs{display:flex;gap:8px;flex-wrap:wrap;margin:12px 0 14px}
    a.tab{border:1px solid #ddd;background:#fff;border-radius:10px;padding:8px 12px;cursor:pointer;font-weight:700;text-decoration:none;color:#111}
    a.tab:hover{border-color:#0057ff;color:#0057ff}
    .hint{font-size:12px;color:#666}
  </style>
</head>
<body>
  <h1>Yiija Share Zrok</h1>
  <div class="tabs">
    $linksHtml
  </div>
  <div class="hint">Tip: use ?s=Comfy or #Comfy for direct entry</div>
  <script>
    const tabs = $($tabs | ConvertTo-Json -Depth 4 -Compress);
    const byKey = {};
    tabs.forEach(t => {
      byKey[(t.name || '').toLowerCase()] = t;
      byKey[(t.safe || '').toLowerCase()] = t;
    });

    const fromQuery = new URLSearchParams(location.search).get('s');
    const fromHash = (location.hash || '').replace(/^#/, '');
    const key = (fromQuery || fromHash || '').toLowerCase();
    const hit = byKey[key];
    if (hit && hit.url) {
      window.location.replace(hit.url);
    }
  </script>
</body>
</html>
"@

[System.IO.File]::WriteAllText($OutFile, $html, [System.Text.UTF8Encoding]::new($false))

