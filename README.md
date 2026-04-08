# Yiija_ShareZrok

這是一個內網穿透及網址轉發空間。  
使用者可輸入本地服務位置，自動更新 Git 並維持固定入口網址。

## 功能

- 啟動 `zrok` 公開穿透
- 取得最新 `https://*.zrok.io` 公開網址
- 自動更新 `index.html` 跳轉頁
- 自動執行 `git add / commit / push`
- 透過固定網址存取內網服務

固定入口網址：`https://yijiastudio.github.io/Yiija_ShareZrok/`

## 需求

- Windows
- `git` 已安裝，且已設定 `user.name`、`user.email`
- GitHub Repo：`https://github.com/YijiaStudio/Yiija_ShareZrok`
- 已安裝 `zrok`（下載：`https://zrok.io/`）
- 需先設定環境變數：`ZROK_ENABLE_TOKEN`

## 授權

- 上游 `zrok` 相關內容遵循 `LICENSE`（Apache License 2.0）。
- 本專案新增腳本/文件另附 `LICENSE-MIT`。

