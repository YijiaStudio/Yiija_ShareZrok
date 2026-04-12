# Yiija_ShareZrok

這是一個內網穿透及網址轉發空間。  
使用者可透過 `services.txt` 自訂多個本地服務位置，自動更新 Git 並維持固定入口網址。

## 功能

- 依 `services.txt` 啟動多個 `zrok` 公開穿透
- 取得多組最新 `https://*.zrok.io` 公開網址
- 自動更新 `index.html` 服務清單頁
- 自動執行 `git add / commit / push`
- 透過固定網址存取內網服務

## services.txt 格式

每行一個服務，可使用以下格式：

- `名稱|http://127.0.0.1:8188`
- `http://127.0.0.1:8188`（名稱自動套用 `service1`、`service2`...）

支援 `#` 開頭註解與空行。

固定入口網址：`https://yijiastudio.github.io/Yiija_ShareZrok/`

## 需求

- Windows
- `git` 已安裝，且已設定 `user.name`、`user.email`
- GitHub Repo：`https://github.com/YijiaStudio/Yiija_ShareZrok`
- 已安裝 `zrok`（下載：`https://zrok.io/`）
- 需先設定環境變數：`ZROK_ENABLE_TOKEN`

## 授權

- 上游 `zrok` 相關內容遵循 `LICENSE`（Apache License 2.0）。