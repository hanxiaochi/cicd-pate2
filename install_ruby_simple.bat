@echo off

:: 强制使用UTF-8编码
chcp 65001 >nul

:: 设置控制台字体以支持UTF-8
reg add HKCU\Console /v CodePage /t REG_DWORD /d 65001 /f >nul
reg add HKCU\Console /v FaceName /t REG_SZ /d "Lucida Console" /f >nul
reg add HKCU\Console /v FontFamily /t REG_DWORD /d 54 /f >nul
reg add HKCU\Console /v FontSize /t REG_DWORD /d 0x000c0000 /f >nul

:: 清除屏幕
cls

echo ==============================
echo Ruby 环境安装助手 (简化版)
echo ==============================
echo 此脚本将帮助您安装Ruby环境

echo.
echo 1. 首先检查是否已安装Ruby...
ruby --version >nul 2>&1
if %errorlevel% equ 0 (
echo Ruby已安装，版本：
ruby --version
echo.
echo 如需继续，请按任意键退出此脚本，然后卸载现有Ruby版本。
pause
exit /b 0
)

:: 使用英文临时目录避免编码问题
echo.
echo 2. 创建临时目录...
set "TEMP_DIR=%SystemDrive%\temp\ruby_install"
mkdir "%TEMP_DIR%" >nul 2>&1
if %errorlevel% neq 0 (
echo 创建临时目录失败，请手动创建：%TEMP_DIR%
pause
exit /b 1
)

echo.
echo 3. 开始下载Ruby安装程序...
echo (此过程可能需要几分钟，请耐心等待)

echo 正在下载RubyInstaller...
powershell -Command "
$ErrorActionPreference = 'Stop';
try {
    Write-Host '正在连接下载服务器...';
    Invoke-WebRequest -Uri 'https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.2.2-1/rubyinstaller-devkit-3.2.2-1-x64.exe' -OutFile '%TEMP_DIR%\rubyinstaller.exe' -Verbose;
    Write-Host '下载完成！';
} catch {
    Write-Host '下载失败！错误信息：' $_.Exception.Message -ForegroundColor Red;
    Write-Host '请手动下载安装程序：';
    Write-Host 'https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.2.2-1/rubyinstaller-devkit-3.2.2-1-x64.exe';
    Read-Host '按Enter键退出';
    exit 1;
}"

if %errorlevel% neq 0 (
echo 下载失败，请检查网络连接。
pause
exit /b 1
)

echo.
echo 4. 运行Ruby安装程序...
echo 请按照安装向导完成安装，并确保勾选"Add Ruby to PATH"选项！
echo.
echo 安装程序启动中...
start /wait "Ruby Installer" "%TEMP_DIR%\rubyinstaller.exe"

:: 验证安装
echo.
echo 5. 验证Ruby安装...
ruby --version >nul 2>&1
if %errorlevel% equ 0 (
echo Ruby安装成功！版本：
ruby --version

echo.
echo 6. 安装bundler...
gem install bundler --no-document
if %errorlevel% equ 0 (
echo bundler安装成功！
) else (
echo bundler安装失败，请稍后手动安装：gem install bundler
)

echo.
echo ==============================
echo 安装完成！
echo 您现在可以运行start.bat来启动CICD工具。
echo ==============================
) else (
echo Ruby安装失败，请尝试手动安装。
echo 安装程序位置：%TEMP_DIR%\rubyinstaller.exe
echo 请右键点击安装程序，选择"以管理员身份运行"
)

echo.
echo 按任意键退出...
pause