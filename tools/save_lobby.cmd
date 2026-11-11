@echo off
setlocal
if "%~1"=="" (
  lune run tools/lobby.luau convert
) else (
  lune run tools/lobby.luau %*
)
exit /b %ERRORLEVEL%
