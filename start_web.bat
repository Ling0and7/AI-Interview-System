@echo off
chcp 65001 >nul
title ProView Web 一键启动

echo ========================================
echo     ProView Web 一键启动脚本
echo ========================================
echo.

:: 检查目录是否存在
if not exist "backend" (
    echo [错误] 未找到 backend 文件夹！
    pause
    exit /b
)
if not exist "frontend" (
    echo [错误] 未找到 frontend 文件夹！
    pause
    exit /b
)

echo [1/3] 正在启动后端 (Flask)...
start "ProView Backend" cmd /k "cd /d %~dp0backend && echo 正在启动后端... && python app.py"

echo [2/3] 等待后端启动（3秒）...
timeout /t 3 >nul

echo [3/3] 正在启动前端 (Vite)...
start "ProView Frontend" cmd /k "cd /d %~dp0frontend && echo 正在启动前端... && npm run dev"

echo.
echo ========================================
echo 启动完成！
echo.
echo 前端地址：
echo   http://localhost:5173/app.html
echo.
echo 后端地址：
echo   http://localhost:5000
echo.
echo 两个命令窗口已打开，请不要关闭它们。
echo 按任意键可关闭此提示窗口...
pause >nul