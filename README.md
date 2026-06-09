## 最新运行教程

双击根目录的start_web.bat，自动开启奥拉玛、后端、前端

## 运行教程—

家人们这是一份启动教程：

首先是启动本地AI模型，我配的是奥拉玛，桌面打开终端，输入：
ollama list
ollama run qwen2.5:14b

然后打开后端，运行代码是：
cd backend
python app.py

最后打开前端，代码是：
cd frontend
npm run dev

测试的简历文件已经打包在里面了

## 你会运行什么

```text
浏览器 -> frontend(Vite)
              |
              -> backend(Flask)
```

Web 开发模式下，前端和后端需要分别启动。

## 前置环境

- Python 3
- Node.js + npm
- Windows / macOS / Linux 都可以做 Web 开发

建议先安装依赖：

```powershell
cd backend
python -m pip install -r requirements.txt

cd ..\frontend
npm install
```

如果你需要 PDF 导出：

```powershell
cd backend
python -m playwright install chromium
```

如果你想复用本机 Edge：

```powershell
$env:PROVIEW_PLAYWRIGHT_CHANNEL = "msedge"
```

## 运行时配置

Web 本地开发默认使用：

- 配置文件：`backend/.env`
- 示例配置：`backend/.env.example`

常见必填项按功能分组：

- 大模型：`DEEPSEEK_API_KEY` / `ERNIE_API_KEY`
- OCR：`PADDLEOCR_API_URL` / `PADDLE_OCR_TOKEN`
- 语音：`BAIDU_APP_KEY` / `BAIDU_SECRET_KEY`

不配置时，相关功能会不可用，但项目本身仍可启动。

## 启动步骤

### 1. 启动后端

```powershell
cd backend
python app.py
```

默认端口：

- `5000`

如果你想改端口，在 `backend/.env` 里设置：

```env
PROVIEW_API_PORT=5000
```

### 2. 启动前端

新开一个终端：

```powershell
cd frontend
npm run dev
```

默认开发地址：

- 落地页：`http://localhost:5173/`
- 业务应用：`http://localhost:5173/app.html`
- 运行时配置页：`http://localhost:5173/app.html#/config`

## Web 开发要点

- 业务应用入口不是根路由，而是 `app.html`
- 前端使用 `hash router`，所以页面地址形如 `app.html#/interview`
- Vite 会把 `/api` 代理到 Flask
- 代理目标默认读取 `PROVIEW_API_PORT`，否则回退到 `5000`

## 常见开发场景

### 只改前端页面

照常运行：

```powershell
cd frontend
npm run dev
```

但如果页面依赖真实接口，后端还是建议一起开。

### 只改后端接口

只启动：

```powershell
cd backend
python app.py
```

然后用前端页面、Postman 或其他客户端调接口。

### 前后端联调

同时启动：

```powershell
cd backend
python app.py
```

```powershell
cd frontend
npm run dev
```

## 构建 Web 产物

```powershell
cd frontend
npm run build
npm run preview
```

构建输出：

- `frontend/dist/index.html`
- `frontend/dist/app.html`

## 什么时候不要用这份文档

如果你的目标是下面任意一种，请转到 [README_DESKTOP.md](README_DESKTOP.md)：

- 调试 Electron 启动链路
- 调试桌面端文件定位/打开能力
- 验证桌面运行时 `.env` / SQLite 存储
- 做 Windows 安装包 / portable 打包
