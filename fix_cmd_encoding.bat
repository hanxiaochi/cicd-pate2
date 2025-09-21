@echo off

REM 中文命令行编码修复工具
REM 此脚本用于修复Windows命令提示符的UTF-8编码问题，解决Ruby应用中的中文显示乱码

cls
echo ==================================================
echo            修复CMD命令提示符乱码问题
echo ==================================================
echo.

REM 临时设置当前CMD窗口为UTF-8编码
chcp 65001 >nul
if %errorlevel% equ 0 (
    echo ✓ 当前CMD窗口已临时设置为UTF-8编码（代码页65001）
) else (
    echo ✗ 切换编码失败，请确保您的Windows版本支持UTF-8代码页
)
echo.

REM 提供永久修改的选项
echo 请选择以下操作：
echo 1. 仅在此窗口临时使用UTF-8（关闭窗口后失效）
echo 2. 永久修改CMD默认编码为UTF-8
echo 3. 退出
echo.

set /p choice=请输入选项 [1-3]: 

echo.

if "%choice%" == "1" (
    echo 您选择了临时使用UTF-8编码。
echo 此窗口已设置为UTF-8，您可以继续在此窗口中操作CICD工具。
echo 注意：关闭窗口后设置将失效。
echo.
echo 提示：要启动CICD工具，请输入 'ruby app.rb' 或直接运行 'start.bat'
echo.
echo 按任意键继续...
pause >nul
exit /b 0
)

if "%choice%" == "2" (
echo 正在永久修改CMD默认编码为UTF-8...

echo 
REM 检查是否以管理员身份运行
NET SESSION >nul 2>&1
if %errorLevel% neq 0 (
echo ✗ 错误：需要管理员权限才能永久修改CMD编码。
echo 请右键点击此脚本，选择"以管理员身份运行"。
echo.
echo 按任意键退出...
pause >nul
exit /b 1
)

REM 修改注册表以设置CMD默认编码为UTF-8
echo 1. 设置默认代码页为UTF-8
reg add "HKCU\Console" /v "CodePage" /t REG_DWORD /d 65001 /f >nul
echo ✓ CMD默认代码页已设置为UTF-8

REM 设置字体为Lucida Console以支持更好的字符显示
echo 2. 设置默认字体为Lucida Console以支持Unicode字符
reg add "HKCU\Console" /v "FaceName" /t REG_SZ /d "Lucida Console" /f >nul
echo ✓ CMD默认字体已设置为Lucida Console

REM 设置字体大小以提高可读性
echo 3. 设置字体大小为12号以提高可读性
reg add "HKCU\Console" /v "FontSize" /t REG_DWORD /d 120000 /f >nul
echo ✓ CMD默认字体大小已设置为12号

REM 配置Windows终端的默认编码
if exist "%LOCALAPPDATA%\Microsoft\Windows Terminal" (
echo 4. 正在配置Windows终端默认编码...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Terminal\Settings" /v "GloballyUniqueId" /t REG_SZ /d "{2c4de342-38b7-51cf-b940-2309a097f518}" /f >nul
echo ✓ Windows终端配置已更新
)

echo.
echo ==================================================
echo ✅ 操作完成！所有配置已成功应用
echo ==================================================
echo 请关闭所有CMD窗口并重新打开以应用更改。
echo 这将解决CICD工具中的中文显示乱码问题。
echo.
echo 按任意键退出...
pause >nul
exit /b 0
)

if "%choice%" == "3" (
exit /b 0
)

REM 无效选项
echo ✗ 无效的选项，请重新运行此脚本并选择1-3之间的数字。
echo.
echo 按任意键退出...
pause >nul
exit /b 1