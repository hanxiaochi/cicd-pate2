@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM 检查Ruby是否已安装
ruby --version >nul 2>&1
if %errorlevel% equ 0 (
echo Ruby已安装，版本：
ruby --version
echo.
echo 如需继续安装或重新安装，请卸载现有Ruby版本后再运行此脚本。
pause
exit /b 0
)

REM 定义Ruby版本和下载链接
set "RUBY_VERSION=3.2.2"
set "INSTALLER_NAME=rubyinstaller-devkit-%RUBY_VERSION%-1-x64.exe"
set "DOWNLOAD_URL=https://github.com/oneclick/rubyinstaller2/releases/download/%RUBY_VERSION%-%RUBY_VERSION:/=%%2F%/%INSTALLER_NAME%"

REM 创建临时下载目录
set "DOWNLOAD_DIR=%TEMP%\ruby_installer"
mkdir "%DOWNLOAD_DIR%" >nul 2>&1
cd "%DOWNLOAD_DIR%"

REM 下载RubyInstaller
if exist "%INSTALLER_NAME%" (
echo 安装程序已存在，跳过下载。
) else (
echo 正在下载Ruby %RUBY_VERSION%安装程序...
echo 下载地址：%DOWNLOAD_URL%

REM 使用PowerShell下载文件
powershell -Command "Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%INSTALLER_NAME%' -Verbose"
if %errorlevel% neq 0 (
echo 下载失败，请检查网络连接或手动下载安装程序。
echo 下载地址：%DOWNLOAD_URL%
pause
exit /b 1
)
)

REM 运行安装程序
if exist "%INSTALLER_NAME%" (
echo 开始安装Ruby %RUBY_VERSION%...
echo 请按照安装向导完成安装，确保勾选添加到PATH选项。
echo.
start /wait "Ruby Installer" "%INSTALLER_NAME%" /verysilent /tasks="assocfiles,modpath"

REM 检查安装是否成功
ruby --version >nul 2>&1
if %errorlevel% equ 0 (
echo.
echo Ruby安装成功！版本：
ruby --version
echo.
echo 正在安装bundler...
gem install bundler --no-document
if %errorlevel% equ 0 (
echo bundler安装成功！
) else (
echo bundler安装失败，请手动安装：gem install bundler
)
echo.
echo 安装完成！您现在可以运行start.bat来启动CICD工具。
) else (
echo Ruby安装失败，请尝试手动安装。
echo 安装程序位置：%DOWNLOAD_DIR%\%INSTALLER_NAME%
)
) else (
echo 安装程序不存在，安装失败。
)

REM 清理临时文件
echo.
echo 正在清理临时文件...
cd %TEMP%
rmdir /s /q "%DOWNLOAD_DIR%" >nul 2>&1

pause
endlocal