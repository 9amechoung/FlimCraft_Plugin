@echo off
rem Double-click installer: FilmCraft goes into a "filmcraft" folder next to this file.
rem Uses install.ps1 next to this file, or downloads it from GitHub when this file was saved alone.
rem Options are passed through, e.g.  install.cmd -Test
setlocal
cd /d "%~dp0"
set "PS1=%~dp0install.ps1"
if not exist "%PS1%" (
    set "PS1=%TEMP%\flimcraft-plugin-install.ps1"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; Invoke-WebRequest 'https://raw.githubusercontent.com/9amechoung/FlimCraft_Plugin/main/install.ps1' -OutFile $env:TEMP\flimcraft-plugin-install.ps1 -UseBasicParsing"
    if errorlevel 1 goto failed
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
if errorlevel 1 goto failed
echo.
echo Done.
pause
exit /b 0
:failed
echo.
echo Installation failed. Read the message above.
pause
exit /b 1
