@echo off
chcp 65001 > nul
title 啟動 ZROK 分享服務

echo #########
echo 啟動 ZROK
echo #########

:: 啟用環境（如果你已經啟用過，可以註解這行）
:: zrok.exe enable public

echo.

:: 提示使用者輸入網址
set /p targetUrl=請輸入你要分享的本機網址（例如 http://127.0.0.1:7860）:

echo.
echo #########
echo 正在分享: %targetUrl%
echo #########

zrok.exe share public %targetUrl%

echo.
echo 分享完成，如有網址，請將其複製給他人使用。
pause
