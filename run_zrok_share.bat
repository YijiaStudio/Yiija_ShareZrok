@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 > nul
title Zrok Auto Sync + GitHub Pages Redirect

set "REPO_URL=https://github.com/YijiaStudio/Zrok.git"
set "PAGES_URL=https://yijiastudio.github.io/Zrok/"
set "URL_FILE=%~dp0last_share_url.txt"
set "INDEX_FILE=%~dp0index.html"
set "PID_FILE=%~dp0zrok_share.pid"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "TMP_URL_FILE=%TEMP%\zrok_share_url.txt"
set "TMP_PID_FILE=%TEMP%\zrok_share_pid.txt"
set "ENABLE_TOKEN=%ZROK_ENABLE_TOKEN%"
set "TARGET_URL=%~1"
if not defined TARGET_URL call :detect_target_url
if not defined TARGET_URL set "TARGET_URL=http://127.0.0.1:8188"

echo ======================================================
echo.
echo [INFO] 本地服務: %TARGET_URL%
echo.
echo ======================================================

if not exist "%~dp0zrok.exe" (
  echo [錯誤] 找不到 zrok.exe
  exit /b 1
)

if not exist "%~dp0.git" (
  echo [INFO] 初始化 Git 倉庫...
  git init
)

for /f "delims=" %%i in ('git config --get user.name 2^>nul') do set "GIT_USER_NAME=%%i"
for /f "delims=" %%i in ('git config --get user.email 2^>nul') do set "GIT_USER_EMAIL=%%i"
if not defined GIT_USER_NAME (
  echo [錯誤] 尚未設定 git user.name
  echo [修正] git config --global user.name "YijiaStudio"
  exit /b 1
)
if not defined GIT_USER_EMAIL (
  echo [錯誤] 尚未設定 git user.email
  echo [修正] git config --global user.email "你的GitHub信箱"
  exit /b 1
)

for /f "delims=" %%i in ('git remote get-url origin 2^>nul') do set "ORIGIN_URL=%%i"
if not defined ORIGIN_URL (
  echo [INFO] 設定 origin -> %REPO_URL%
  git remote add origin "%REPO_URL%"
) else (
  if /I not "!ORIGIN_URL!"=="%REPO_URL%" (
    echo [INFO] 更新 origin URL
    git remote set-url origin "%REPO_URL%"
  )
)

echo.
echo [INFO] 重新啟用 zrok...
zrok disable >nul 2>&1
if not defined ENABLE_TOKEN (
  echo [錯誤] 未設定 ZROK_ENABLE_TOKEN
  echo [修正] 在系統環境變數新增 ZROK_ENABLE_TOKEN 後重試
  exit /b 1
)
zrok.exe enable "%ENABLE_TOKEN%"
if errorlevel 1 (
  echo [錯誤] zrok enable 失敗，請先手動確認 token 是否有效
  exit /b 1
)

echo [INFO] 清理舊的 zrok share 背景程序
if exist "%PID_FILE%" (
  set /p OLD_PID=<"%PID_FILE%"
  if defined OLD_PID (
    "%PS_EXE%" -NoProfile -Command "try { Stop-Process -Id %OLD_PID% -Force -ErrorAction Stop } catch {}" >nul 2>&1
  )
  del /f /q "%PID_FILE%" >nul 2>&1
)
"%PS_EXE%" -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'zrok.exe' -and $_.CommandLine -match 'share public' } | ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {} }" >nul 2>&1

echo [INFO] 背景啟動 zrok share（不開新視窗）
start "" /b cmd /c ""%~dp0zrok.exe" share public "%TARGET_URL%" --headless"
for /l %%n in (1,1,10) do (
  set "SHARE_PID="
  if exist "%TMP_PID_FILE%" del /f /q "%TMP_PID_FILE%" >nul 2>&1
  "%PS_EXE%" -NoProfile -Command "$target='%TARGET_URL%'; $p = Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'zrok.exe' -and $_.CommandLine -match 'share public' -and $_.CommandLine -match [regex]::Escape($target) } | Sort-Object CreationDate -Descending | Select-Object -First 1; if ($p) { $p.ProcessId | Out-File -Encoding ascii '%TMP_PID_FILE%' }" >nul 2>&1
  if exist "%TMP_PID_FILE%" (
    set /p SHARE_PID=<"%TMP_PID_FILE%"
    del /f /q "%TMP_PID_FILE%" >nul 2>&1
  )
  if defined SHARE_PID goto :pid_ready
  timeout /t 1 /nobreak >nul
)
:pid_ready
if not defined SHARE_PID (
  echo [錯誤] 無法啟動 zrok share 背景程序
  exit /b 1
)
> "%PID_FILE%" echo %SHARE_PID%

set "SHARE_URL="
if exist "%TMP_URL_FILE%" del /f /q "%TMP_URL_FILE%" >nul 2>&1
for /l %%n in (1,1,90) do (
  "%PS_EXE%" -NoProfile -Command "$target = '%TARGET_URL%'; $json = & '%~dp0zrok.exe' overview 2>$null; if (-not $json) { exit 0 }; $obj = $json | ConvertFrom-Json; $shares = @(); foreach ($env in $obj.environments) { if ($env.shares) { $shares += $env.shares } }; $matched = $shares | Where-Object { $_.backendProxyEndpoint -eq $target -and $_.frontendEndpoint } | Sort-Object createdAt -Descending | Select-Object -First 1; if (-not $matched) { $matched = $shares | Where-Object { $_.shareMode -eq 'public' -and $_.frontendEndpoint } | Sort-Object createdAt -Descending | Select-Object -First 1 }; if ($matched) { $matched.frontendEndpoint | Out-File -Encoding ascii '%TMP_URL_FILE%' }" >nul 2>&1
  if exist "%TMP_URL_FILE%" (
    set /p SHARE_URL=<"%TMP_URL_FILE%"
    del /f /q "%TMP_URL_FILE%" >nul 2>&1
  )
  if defined SHARE_URL goto :got_url
  timeout /t 1 /nobreak >nul
)

echo [錯誤] 90 秒內抓不到 zrok 公開網址
"%PS_EXE%" -NoProfile -Command "try { Stop-Process -Id %SHARE_PID% -Force -ErrorAction Stop } catch {}" >nul 2>&1
del /f /q "%PID_FILE%" >nul 2>&1
exit /b 1

:got_url
echo [OK] zrok 公開網址: !SHARE_URL!
> "%URL_FILE%" echo !SHARE_URL!

(
  echo ^<!doctype html^>
  echo ^<html lang="zh-Hant"^>
  echo ^<head^>
  echo   ^<meta charset="utf-8" /^>
  echo   ^<meta name="viewport" content="width=device-width, initial-scale=1" /^>
  echo   ^<meta http-equiv="refresh" content="0; url=!SHARE_URL!" /^>
  echo   ^<title^>Zrok Redirect^</title^>
  echo   ^<style^>body{font-family:Segoe UI,Arial,sans-serif;padding:32px;line-height:1.6;}code{background:#f4f4f4;padding:2px 6px;border-radius:4px;}^</style^>
  echo ^</head^>
  echo ^<body^>
  echo   ^<h1^>Redirecting...^</h1^>
  echo   ^<p^>如果沒有自動跳轉，請點這裡：^<a href="!SHARE_URL!"^>!SHARE_URL!^</a^>^</p^>
  echo   ^<p^>Updated at: ^<code^>%date% %time%^</code^>^</p^>
  echo ^</body^>
  echo ^</html^>
) > "%INDEX_FILE%"

echo.
echo [INFO] 提交並推送跳轉頁到 GitHub...
git add index.html last_share_url.txt >nul 2>&1
git commit -m "chore: update zrok redirect target to !SHARE_URL!" >nul 2>&1
if errorlevel 1 (
  git diff --cached --quiet
  if errorlevel 1 (
    echo [錯誤] commit 失敗，請執行 git commit 查看詳細原因
    exit /b 1
  )
  echo [INFO] 沒有可提交變更（網址可能相同）
)

git branch -M main >nul 2>&1
git push -u origin main
if errorlevel 1 (
  echo [錯誤] 推送失敗。請先完成 GitHub 認證後重試。
  echo [提示] 你可以先手動跑: git push -u origin main
  exit /b 1
)

echo.
echo [完成] 固定入口網址:
echo %PAGES_URL%
start "" "%PAGES_URL%"
echo.
echo [提示] 下次只要再次執行這個 .bat，就會自動更新跳轉網址。
exit /b 0

:detect_target_url
set "TARGET_URL="
call :try_url "http://172.30.20.1:8188"
if defined TARGET_URL exit /b 0
call :try_url "http://127.0.0.1:8188"
if defined TARGET_URL exit /b 0
call :try_url "http://127.0.0.1:7860"
if defined TARGET_URL exit /b 0
call :try_url "http://localhost:8188"
if defined TARGET_URL exit /b 0
call :try_url "http://localhost:7860"
exit /b 0

:try_url
set "CANDIDATE_URL=%~1"
"%PS_EXE%" -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '%CANDIDATE_URL%' -TimeoutSec 3 -UseBasicParsing; if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 set "TARGET_URL=%CANDIDATE_URL%"
exit /b 0