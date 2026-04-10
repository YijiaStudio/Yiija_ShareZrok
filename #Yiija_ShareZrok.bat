@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 > nul
title Zrok Auto Sync (Multi Services)

set "REPO_URL=https://github.com/YijiaStudio/Yiija_ShareZrok.git"
set "PAGES_URL=https://yijiastudio.github.io/Yiija_ShareZrok/"
set "SERVICE_FILE=%~dp0services.txt"
set "URL_FILE=%~dp0last_share_url.txt"
set "URLS_FILE=%~dp0share_urls.txt"
set "INDEX_FILE=%~dp0index.html"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "TMP_URL_FILE=%TEMP%\zrok_share_url.txt"
set "TMP_SERVICE_FILE=%TEMP%\zrok_services_parsed.txt"
set "ENABLE_TOKEN=7SJYQKzQ5LKG"
set "SERVICE_COUNT=0"
set "CACHE_BUST=%RANDOM%%RANDOM%%RANDOM%"

if not exist "%~dp0zrok.exe" (
  echo [ERROR] zrok.exe not found in current folder.
  exit /b 1
)

if not exist "%SERVICE_FILE%" (
  > "%SERVICE_FILE%" echo # 每行一個服務，支援兩種格式
  >> "%SERVICE_FILE%" echo # 1^) 名稱^|URL
  >> "%SERVICE_FILE%" echo # 2^) 只有 URL（名稱會自動變成 service1, service2...）
  >> "%SERVICE_FILE%" echo comfy^|http://127.0.0.1:8188
  echo [INFO] Created %SERVICE_FILE%
  echo [INFO] Please edit it and rerun.
  exit /b 1
)

for /f "delims=" %%i in ('git remote get-url origin 2^>nul') do set "ORIGIN_URL=%%i"
if not defined ORIGIN_URL git remote add origin "%REPO_URL%"
if defined ORIGIN_URL (
  if /I not "%ORIGIN_URL%"=="%REPO_URL%" git remote set-url origin "%REPO_URL%"
)

if exist "%TMP_SERVICE_FILE%" del /f /q "%TMP_SERVICE_FILE%" >nul 2>&1
"%PS_EXE%" -NoProfile -Command "$idx=1; Get-Content -Path '%SERVICE_FILE%' | ForEach-Object { $line=$_.Trim(); if (-not $line -or $line.StartsWith('#')) { return }; if ($line.Contains('|')) { $parts=$line.Split('|',2); $name=$parts[0].Trim(); $url=$parts[1].Trim(); if (-not $name) { $name='service' + $idx } } else { $name='service' + $idx; $url=$line }; if ($url) { '{0}|{1}' -f $name,$url; $idx++ } } | Out-File -Encoding ascii '%TMP_SERVICE_FILE%'" >nul 2>&1

for /f "usebackq tokens=1* delims=|" %%a in ("%TMP_SERVICE_FILE%") do (
  set /a SERVICE_COUNT+=1
  set "SERVICE_NAME_!SERVICE_COUNT!=%%~a"
  set "SERVICE_URL_!SERVICE_COUNT!=%%~b"
)

if %SERVICE_COUNT% leq 0 (
  echo [ERROR] No valid service found in services.txt
  exit /b 1
)

echo ======================================================
echo [INFO] Services from services.txt: %SERVICE_COUNT%
for /l %%i in (1,1,%SERVICE_COUNT%) do (
  call echo [INFO] %%i. %%SERVICE_NAME_%%i%% ^| %%SERVICE_URL_%%i%%
)
echo ======================================================

echo [INFO] Enabling zrok...
zrok disable >nul 2>&1
zrok.exe enable "%ENABLE_TOKEN%"
if errorlevel 1 (
  echo [ERROR] zrok enable failed.
  exit /b 1
)

echo [INFO] Cleaning previous background share process...

for /l %%i in (1,1,%SERVICE_COUNT%) do (
  call set "TARGET_URL=%%SERVICE_URL_%%i%%"
  call set "SERVICE_NAME=%%SERVICE_NAME_%%i%%"
  echo [INFO] Starting: !SERVICE_NAME! ^| !TARGET_URL!
  start "" /b cmd /c ""%~dp0zrok.exe" share public "!TARGET_URL!" --headless" >nul 2>&1
)

if exist "%URLS_FILE%" del /f /q "%URLS_FILE%" >nul 2>&1
set "FIRST_URL="
for /l %%i in (1,1,%SERVICE_COUNT%) do (
  call set "TARGET_URL=%%SERVICE_URL_%%i%%"
  call set "SERVICE_NAME=%%SERVICE_NAME_%%i%%"
  call :resolve_url "!TARGET_URL!" SHARE_URL
  if not defined SHARE_URL (
    echo [ERROR] Could not get zrok public URL for !SERVICE_NAME! within 90 seconds.
    exit /b 1
  )
  echo [OK] !SERVICE_NAME! = !SHARE_URL!
  if not defined FIRST_URL set "FIRST_URL=!SHARE_URL!"
  set "PUBLIC_URL_%%i=!SHARE_URL!"
  >> "%URLS_FILE%" echo !SERVICE_NAME!^|!SHARE_URL!
)

if not defined FIRST_URL (
  echo [ERROR] No public URL resolved.
  exit /b 1
)
> "%URL_FILE%" echo !FIRST_URL!

echo [INFO] Writing per-service redirect pages...
for /l %%i in (1,1,%SERVICE_COUNT%) do (
  call set "SERVICE_NAME=%%SERVICE_NAME_%%i%%"
  call set "SHARE_URL=%%PUBLIC_URL_%%i%%"

  set "SAFE_NAME=!SERVICE_NAME!"
  if not defined SAFE_NAME set "SAFE_NAME=service"
  set "SAFE_NAME=!SAFE_NAME: =_!"

  if not exist "%~dp0!SAFE_NAME!" mkdir "%~dp0!SAFE_NAME!" >nul 2>&1

  set "SAFE_DIR=%~dp0!SAFE_NAME!"
  "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate-redirect.ps1" -Name "!SERVICE_NAME!" -Fallback "!SHARE_URL!" -OutDir "!SAFE_DIR!" -CacheBust "%CACHE_BUST%" >nul 2>&1

  echo [OK] Page: /!SAFE_NAME!/  -^>  !SERVICE_NAME!
)

echo [INFO] Writing root tab page...
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate-tabs.ps1" -ServicesFile "%SERVICE_FILE%" -ShareUrlsFile "%URLS_FILE%" -OutFile "%INDEX_FILE%" >nul 2>&1

echo [INFO] Committing redirect update...
git add index.html last_share_url.txt share_urls.txt generate-redirect.ps1 generate-tabs.ps1
for /l %%i in (1,1,%SERVICE_COUNT%) do (
  call set "SERVICE_NAME=%%SERVICE_NAME_%%i%%"
  set "SAFE_NAME=!SERVICE_NAME!"
  if not defined SAFE_NAME set "SAFE_NAME=service"
  set "SAFE_NAME=!SAFE_NAME: =_!"
  git add "!SAFE_NAME!\index.html" >nul 2>&1
)
git commit -m "chore: update zrok public service links" >nul 2>&1
if errorlevel 1 (
  git diff --cached --quiet
  if errorlevel 1 (
    echo [ERROR] Commit failed.
    exit /b 1
  )
  echo [INFO] No new redirect change to commit.
)

echo [INFO] Pushing to GitHub...
git push origin main >nul 2>&1
if errorlevel 1 (
  echo [WARN] Push rejected, trying rebase...
  git rebase --abort >nul 2>&1
  git stash push -m "__zrok_auto_rebase__" >nul 2>&1
  git pull --rebase origin main >nul 2>&1
  set "REBASE_OK=%ERRORLEVEL%"
  git stash pop >nul 2>&1
  if not "%REBASE_OK%"=="0" (
    echo [ERROR] Rebase failed. Push not completed.
    exit /b 1
  )
  git push origin main >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] Push failed after rebase.
    exit /b 1
  )
)

echo [DONE] Push success: %PAGES_URL%
start "" "%PAGES_URL%"
exit /b 0

:resolve_url
setlocal
set "TARGET=%~1"
set "FOUND_URL="
if exist "%TMP_URL_FILE%" del /f /q "%TMP_URL_FILE%" >nul 2>&1
for /l %%n in (1,1,90) do (
  "%PS_EXE%" -NoProfile -Command "$target = '%TARGET%'; $json = & '%~dp0zrok.exe' overview 2>$null; if (-not $json) { exit 0 }; $obj = $json | ConvertFrom-Json; $shares = @(); foreach ($env in $obj.environments) { if ($env.shares) { $shares += $env.shares } }; $matched = $shares | Where-Object { $_.backendProxyEndpoint -eq $target -and $_.shareMode -eq 'public' -and $_.frontendEndpoint } | Sort-Object createdAt -Descending | Select-Object -First 1; if ($matched) { $matched.frontendEndpoint | Out-File -Encoding ascii '%TMP_URL_FILE%' }" >nul 2>&1
  if exist "%TMP_URL_FILE%" (
    set /p FOUND_URL=<"%TMP_URL_FILE%"
    del /f /q "%TMP_URL_FILE%" >nul 2>&1
  )
  if defined FOUND_URL goto :resolve_url_done
  timeout /t 1 /nobreak >nul
)
:resolve_url_done
endlocal & set "%~2=%FOUND_URL%"
exit /b 0
