@echo off
chcp 65001 >nul

REM 检查Ruby是否安装
ruby --version >nul 2>&1
if %errorlevel% neq 0 (
echo 错误：未检测到Ruby环境。
echo 请先安装Ruby 2.5或更高版本，然后再尝试运行此脚本。
echo 安装完成后，您还需要安装bundler：gem install bundler
echo 然后运行：bundle install
echo 最后运行：ruby app.rb
pause
exit /b 1
)

REM 检查bundler是否安装
bundle --version >nul 2>&1
if %errorlevel% neq 0 (
echo 正在安装bundler...
gem install bundler
if %errorlevel% neq 0 (
echo 安装bundler失败，请手动安装：gem install bundler
pause
exit /b 1
)
)

REM 安装依赖
echo 正在安装项目依赖...
bundle install
if %errorlevel% neq 0 (
echo 安装依赖失败，请检查错误信息
pause
exit /b 1
)

REM 启动应用
echo 正在启动CICD工具...
echo 请打开浏览器访问 http://localhost:4567
ruby app.rb

pause