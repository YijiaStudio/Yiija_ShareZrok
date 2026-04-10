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

$tabsJson = ($tabs | ConvertTo-Json -Depth 4 -Compress)

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
    .tab{border:1px solid #ddd;background:#fff;border-radius:10px;padding:8px 12px;cursor:pointer;font-weight:700}
    .tab[aria-selected="true"]{border-color:#0057ff;color:#0057ff}
    .panel{border:1px solid #eee;border-radius:14px;padding:14px}
    .row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
    .url{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;word-break:break-all}
    a.btn{display:inline-block;background:#0057ff;color:#fff;padding:8px 12px;border-radius:10px;text-decoration:none;font-weight:800}
    a.link{color:#0057ff;text-decoration:none;font-weight:700}
  </style>
</head>
<body>
  <h1>Yiija Share Zrok</h1>
  <div class="tabs" id="tabs" role="tablist" aria-label="Services"></div>
  <div class="panel">
    <div class="row">
      <a class="btn" id="open" href="#" target="_blank" rel="noopener">Open</a>
      <a class="link" id="perma" href="#">Permalink</a>
    </div>
    <div class="url" id="url" style="margin-top:10px"></div>
  </div>
  <script>
    const tabs = $tabsJson;
    const tabsEl = document.getElementById('tabs');
    const urlEl = document.getElementById('url');
    const openEl = document.getElementById('open');
    const permaEl = document.getElementById('perma');

    function render() {
      tabsEl.innerHTML = '';
      tabs.forEach((t, i) => {
        const b = document.createElement('button');
        b.className = 'tab';
        b.type = 'button';
        b.setAttribute('role', 'tab');
        b.setAttribute('aria-selected', i === 0 ? 'true' : 'false');
        b.textContent = t.name;
        b.addEventListener('click', () => select(i));
        tabsEl.appendChild(b);
      });
      if (tabs.length) select(0);
    }

    function select(i) {
      const btns = Array.from(tabsEl.querySelectorAll('.tab'));
      btns.forEach((b, idx) => b.setAttribute('aria-selected', String(idx === i)));
      const t = tabs[i];
      urlEl.textContent = t.url || '(not found yet)';
      openEl.href = t.url || '#';
      permaEl.textContent = "Permalink: /" + t.safe + "/";
      permaEl.href = "./" + t.safe + "/";
    }

    render();
  </script>
</body>
</html>
"@

[System.IO.File]::WriteAllText($OutFile, $html, [System.Text.UTF8Encoding]::new($false))

