@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 > nul
title Zrok Auto Sync + GitHub Pages Redirect

set "REPO_URL=https://github.com/YijiaStudio/Zrok.git"
set "PAGES_URL=https://yijiastudio.github.io/Zrok/"
set "LOG_FILE=%~dp0zrok_share.log"
set "URL_FILE=%~dp0last_share_url.txt"
set "INDEX_FILE=%~dp0index.html"
set "TARGET_URL=%~1"
if not defined TARGET_URL set "TARGET_URL=http://127.0.0.1:7860"

echo ===========================
echo Zrok -> GitHub 自動同步器
echo ===========================
echo.

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
zrok.exe enable 7SJYQKzQ5LKG
if errorlevel 1 (
  echo [錯誤] zrok enable 失敗
  exit /b 1
)

if exist "%LOG_FILE%" del /f /q "%LOG_FILE%"

echo [INFO] 啟動 zrok share 視窗（會常駐，關閉它就會中斷穿透）
start "zrok-share-public" cmd /c ""%~dp0zrok.exe" share public "%TARGET_URL%" > "%LOG_FILE%" 2>&1"

set "SHARE_URL="
for /l %%n in (1,1,90) do (
  for /f "tokens=1,* delims= " %%a in ('findstr /r /c:"https://[a-zA-Z0-9.-]*\.zrok\.io" "%LOG_FILE%" 2^>nul') do (
    set "CANDIDATE=%%a"
    if /I "!CANDIDATE:~0,8!"=="https://" set "SHARE_URL=!CANDIDATE!"
  )
  if defined SHARE_URL goto :got_url
  timeout /t 1 /nobreak >nul
)

echo [錯誤] 90 秒內抓不到 zrok 公開網址，請查看 zrok_share.log
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
echo.
echo [提示] 下次只要再次執行這個 .bat，就會自動更新跳轉網址。
echo [INFO] 本次本地來源網址: %TARGET_URL%