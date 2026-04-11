@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 > nul
title Zrok Auto Sync (Multi Services) - Optimized

:: ================= 設定區 =================
set "REPO_URL=https://github.com/YijiaStudio/Yiija_ShareZrok.git"
set "PAGES_URL=https://yijiastudio.github.io/Yiija_ShareZrok/"
set "SERVICE_FILE=%~dp0services.txt"
set "URL_FILE=%~dp0last_share_url.txt"
set "URLS_FILE=%~dp0share_urls.txt"
set "INDEX_FILE=%~dp0index.html"
set "NODES_DIR=%~dp0nodes"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "TMP_URL_FILE=%TEMP%\zrok_share_url.txt"
set "TMP_SERVICE_FILE=%TEMP%\zrok_services_parsed.txt"
set "TMP_ACTIVE_SAFE_FILE=%TEMP%\zrok_active_safe_names.txt"
set "ENABLE_TOKEN=7SJYQKzQ5LKG"
set "NODE_NAME=%COMPUTERNAME%"
if not defined NODE_NAME set "NODE_NAME=pc"
set "NODE_NAME=%NODE_NAME: =_%"
set "NODE_DIR=%NODES_DIR%\%NODE_NAME%"
set "NODE_MANAGED_FILE=%NODE_DIR%\managed_services.txt"
set "NODE_URLS_FILE=%NODE_DIR%\share_urls.txt"
set "NODE_LAST_FILE=%NODE_DIR%\last_share_url.txt"
set "CACHE_BUST=%RANDOM%%RANDOM%"

:: ================= 1. 環境檢查 =================
if not exist "%~dp0zrok.exe" (
    echo [ERROR] zrok.exe not found in current folder.
    pause & exit /b 1
)

:: 檢查 Git 鎖定狀態 (預防 fatal: Unable to create index.lock)
if exist "%~dp0.git\index.lock" (
    echo [WARN] Detected stale Git lock. Removing...
    del /f /q "%~dp0.git\index.lock" >nul 2>&1
)

if not exist "%SERVICE_FILE%" (
    > "%SERVICE_FILE%" echo # 名稱^|URL
    >> "%SERVICE_FILE%" echo comfy^|http://127.0.0.1:8188
    >> "%SERVICE_FILE%" echo trellis^|http://127.0.0.1:7860
    echo [INFO] Created %SERVICE_FILE%, please edit and rerun.
    pause & exit /b 1
)

:: Git 遠端檢查
for /f "delims=" %%i in ('git remote get-url origin 2^>nul') do set "ORIGIN_URL=%%i"
if not defined ORIGIN_URL (
    git remote add origin "%REPO_URL%"
) else (
    if /I not "%ORIGIN_URL%"=="%REPO_URL%" git remote set-url origin "%REPO_URL%"
)

:: ================= 2. 解析服務列表 =================
if exist "%TMP_SERVICE_FILE%" del /f /q "%TMP_SERVICE_FILE%" >nul 2>&1
"%PS_EXE%" -NoProfile -Command "$idx=1; Get-Content -Path '%SERVICE_FILE%' | ForEach-Object { $line=$_.Trim(); if (-not $line -or $line.StartsWith('#')) { return }; if ($line.Contains('|')) { $parts=$line.Split('|',2); $name=$parts[0].Trim(); $url=$parts[1].Trim() } else { $name='service' + $idx; $url=$line }; if ($url) { '{0}|{1}' -f $name,$url; $idx++ } } | Out-File -Encoding ascii '%TMP_SERVICE_FILE%'"

set SERVICE_COUNT=0
for /f "usebackq tokens=1* delims=|" %%a in ("%TMP_SERVICE_FILE%") do (
    set /a SERVICE_COUNT+=1
    set "SERVICE_NAME_!SERVICE_COUNT!=%%~a"
    set "SERVICE_URL_!SERVICE_COUNT!=%%~b"
)

echo ======================================================
echo [INFO] Node: %NODE_NAME% ^| Services: %SERVICE_COUNT%
echo ======================================================

:: ================= 3. Zrok 啟動 =================
echo [INFO] Enabling zrok...
zrok disable >nul 2>&1
zrok.exe enable "%ENABLE_TOKEN%" >nul 2>&1

echo [INFO] Detecting online services...
set ACTIVE_COUNT=0
for /l %%i in (1,1,%SERVICE_COUNT%) do (
    call set "TARGET_URL=%%SERVICE_URL_%%i%%"
    call set "SERVICE_NAME=%%SERVICE_NAME_%%i%%"
    call :is_url_alive "!TARGET_URL!" URL_ALIVE
    if "!URL_ALIVE!"=="1" (
        set /a ACTIVE_COUNT+=1
        set "ACTIVE_NAME_!ACTIVE_COUNT!=!SERVICE_NAME!"
        set "ACTIVE_URL_!ACTIVE_COUNT!=!TARGET_URL!"
        echo [OK] Online: !SERVICE_NAME!
        start "" /b cmd /c ""%~dp0zrok.exe" share public "!TARGET_URL!" --headless" >nul 2>&1
    ) else (
        echo [SKIP] Offline: !SERVICE_NAME!
    )
)

if %ACTIVE_COUNT% leq 0 echo [ERROR] No online services. & pause & exit /b 1

:: ================= 4. 生成頁面 =================
timeout /t 5 /nobreak >nul
if not exist "%NODE_DIR%" mkdir "%NODE_DIR%" >nul 2>&1
if exist "%NODE_URLS_FILE%" del /q "%NODE_URLS_FILE%" >nul 2>&1

for /l %%i in (1,1,%ACTIVE_COUNT%) do (
    call set "TARGET_URL=%%ACTIVE_URL_%%i%%"
    call set "SERVICE_NAME=%%ACTIVE_NAME_%%i%%"
    call :resolve_url "!TARGET_URL!" SHARE_URL
    
    if defined SHARE_URL (
        echo [URL] !SERVICE_NAME! = !SHARE_URL!
        if %%i==1 set "FIRST_URL=!SHARE_URL!"
        set "PUBLIC_URL_%%i=!SHARE_URL!"
        >> "%NODE_URLS_FILE%" echo !SERVICE_NAME!^|!SHARE_URL!
        
        set "SAFE_NAME=!SERVICE_NAME: =_!"
        if not exist "%NODE_DIR%\!SAFE_NAME!" mkdir "%NODE_DIR%\!SAFE_NAME!"
        "%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate-redirect.ps1" -Name "!SERVICE_NAME!" -Fallback "!SHARE_URL!" -OutDir "%NODE_DIR%\!SAFE_NAME!" -CacheBust "%CACHE_BUST%" >nul 2>&1
        echo !SAFE_NAME! >> "%TMP_ACTIVE_SAFE_FILE%"
    )
)

> "%URL_FILE%" echo !FIRST_URL!
> "%NODE_LAST_FILE%" echo !FIRST_URL!
copy /y "%NODE_URLS_FILE%" "%URLS_FILE%" >nul 2>&1

:: 生成首頁
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0generate-root-links.ps1" -NodesDir "%NODES_DIR%" -OutFile "%INDEX_FILE%" >nul 2>&1

:: ================= 5. Git 同步 (強化版) =================
echo [INFO] Committing and Pushing to GitHub...

:: 再次確保沒有鎖定檔
if exist "%~dp0.git\index.lock" del /f /q "%~dp0.git\index.lock" >nul 2>&1

git add .
git commit -m "chore: update zrok links from %NODE_NAME% [skip ci]" >nul 2>&1

:: 核心：推送前的強制同步
git pull --rebase origin main >nul 2>&1
if errorlevel 1 (
    echo [WARN] Rebase conflict detected, trying to resolve...
    git rebase --abort >nul 2>&1
    git pull origin main --strategy-option=theirs --no-edit >nul 2>&1
)

git push origin main
if errorlevel 1 (
    echo [ERROR] Push failed. Attempting force sync...
    git fetch origin
    git reset --soft origin/main
    git add .
    git commit -m "chore: forced update zrok links" >nul 2>&1
    git push origin main
)

if errorlevel 0 (
    echo [DONE] Successfully updated: %PAGES_URL%
    start "" "%PAGES_URL%"
) else (
    echo [ERROR] Git sync failed. Check your network or permissions.
)

exit /b 0

:: ================= 工具函式 =================
:resolve_url
setlocal
set "FOUND_URL="
for /l %%n in (1,1,30) do (
    "%PS_EXE%" -NoProfile -Command "$t='%~1'; $j=&'%~dp0zrok.exe' overview; if($j){$o=$j|ConvertFrom-Json; $s=$o.environments.shares | where{$_.backendProxyEndpoint -eq $t} | select -first 1; if($s){$s.frontendEndpoint}}" > "%TMP_URL_FILE%" 2>nul
    set /p FOUND_URL=<"%TMP_URL_FILE%"
    if defined FOUND_URL goto :resolve_done
    timeout /t 2 /nobreak >nul
)
:resolve_done
endlocal & set "%~2=%FOUND_URL%"
exit /b 0

:is_url_alive
setlocal
"%PS_EXE%" -NoProfile -Command "try{ $r=Invoke-WebRequest -Uri '%~1' -TimeoutSec 2 -UseBasicParsing; exit 0 }catch{ exit 1 }" >nul 2>&1
if errorlevel 1 (set "A=0") else (set "A=1")
endlocal & set "%~2=%A%"
exit /b 0