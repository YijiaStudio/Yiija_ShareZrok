# Yijia_Zrok

這是一個內網穿透及網址轉發工具。  
使用者可輸入本地服務位置，自動更新 Git 並維持固定入口網址。

## 功能

- 啟動 `zrok` 公開穿透
- 取得最新 `https://*.zrok.io` 公開網址
- 自動更新 `index.html` 跳轉頁
- 自動執行 `git add / commit / push`
- 透過固定網址存取內網服務

固定入口網址：`https://yijiastudio.github.io/Zrok/`

## 使用方式

```bat
run_zrok_share.bat
```

指定本地服務：

```bat
run_zrok_share.bat "http://127.0.0.1:3000"
```

預設本地服務：

```text
http://127.0.0.1:7860
```

## 需求

- Windows
- `git` 已安裝，且已設定 `user.name`、`user.email`
- GitHub Repo：`https://github.com/YijiaStudio/Zrok`
- 專案目錄內包含 `zrok.exe`

## 主要檔案

- `run_zrok_share.bat`：一鍵自動化腳本
- `index.html`：GitHub Pages 跳轉頁
- `last_share_url.txt`：最近一次公開網址
