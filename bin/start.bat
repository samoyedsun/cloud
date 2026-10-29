@echo off
rem Windows launcher. Run from the project root:
rem   bin\start.bat
setlocal

rem runtime dir: parent of this script's dir -> project root
for %%i in ("%~dp0..") do set "ROOT=%%~fi"
if not exist "%ROOT%\skynet\skynet.exe" (
    echo [start.bat] skynet.exe not found.
    echo Build and install first:
    echo   xmake f -m release -y
    echo   xmake -y
    echo   xmake install -y
    exit /b 1
)

set DAEMON=false
set NODENAME="test"
set DEBUG_MODE="DEBUG"
set LOG_PATH="./run/"
set ETCDHOST="127.0.0.1:8101"
set ENV="dev"

if not exist "%ROOT%\run" mkdir "%ROOT%\run"

cd /d "%ROOT%"
skynet\skynet.exe etc\config.lua
