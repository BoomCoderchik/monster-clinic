@echo off
rem Local server for the Web build (Monster Clinic 13).
rem Picks whatever is installed: Python, Node.js or PHP.
rem
rem   run-web-preview.cmd            port 8080
rem   run-web-preview.cmd 9000       another port
rem
rem Full sound works only on http://localhost:... (browser requirement:
rem AudioWorklet needs a secure context). A LAN address also works, but with
rem the reduced audio fallback.
rem
rem Text here is ASCII-only on purpose: cmd.exe renders non-ASCII batch files
rem depending on the console code page. The code page is switched below so that
rem the Russian output of the Node.js server is readable.
chcp 65001 >nul
setlocal
set PORT=%~1
if "%PORT%"=="" set PORT=8080
cd /d "%~dp0"

if not exist "web\index.html" (
	echo [x] web\index.html not found next to this script.
	echo     Run run-web-preview.cmd from the project root.
	pause
	exit /b 1
)

echo Playing at: http://localhost:%PORT%/
echo Stop the server: Ctrl+C
echo.

where py >nul 2>nul
if not errorlevel 1 (
	py -m http.server %PORT% --bind 0.0.0.0 --directory web
	goto :done
)

where python >nul 2>nul
if not errorlevel 1 (
	python -m http.server %PORT% --bind 0.0.0.0 --directory web
	goto :done
)

where node >nul 2>nul
if not errorlevel 1 (
	node "tools\serve_web.mjs" %PORT% --open
	goto :done
)

where php >nul 2>nul
if not errorlevel 1 (
	php -S 0.0.0.0:%PORT% -t web
	goto :done
)

echo [x] Neither Python, Node.js nor PHP was found.
echo     Install one of them and run this file again:
echo       winget install Python.Python.3.12
echo       winget install OpenJS.NodeJS.LTS
pause
exit /b 1

:done
endlocal
