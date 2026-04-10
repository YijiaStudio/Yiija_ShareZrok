param(
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][string]$Fallback,
  [Parameter(Mandatory = $true)][string]$OutDir,
  [Parameter(Mandatory = $true)][string]$CacheBust
)

$ErrorActionPreference = 'Stop'

$raw = "https://raw.githubusercontent.com/YijiaStudio/Yiija_ShareZrok/main/share_urls.txt?ts=$CacheBust"

$html = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
  <meta http-equiv="Pragma" content="no-cache" />
  <meta http-equiv="Expires" content="0" />
  <title>$Name</title>
  <script>
    const name = "$Name";
    const fallback = "$Fallback";
    const raw = "$raw";
    fetch(raw, { cache: "no-store" })
      .then(r => r.text())
      .then(t => {
        const lines = t.split(/\r?\n/).map(s => s.trim()).filter(Boolean);
        const hit = lines.map(l => l.split('|')).find(p => (p[0] || '').trim() === name);
        const u = hit ? (hit[1] || '').trim() : '';
        window.location.replace(u || fallback);
      })
      .catch(() => window.location.replace(fallback));
  </script>
</head>
<body style="margin:0;background:#fff;"></body>
</html>
"@

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
[System.IO.File]::WriteAllText((Join-Path $OutDir 'index.html'), $html, [System.Text.UTF8Encoding]::new($false))
