@echo off
rem Map authoring entry point for Windows without Git Bash. Same arguments as
rem tools/save_map.sh (except --all, which needs bash):
rem     tools\save_map.cmd new TestMap
rem     tools\save_map.cmd TestMap
rem     tools\save_map.cmd status
setlocal
cd /d "%~dp0.."
set CMD=%1
if "%CMD%"=="" goto passthrough
if /i "%CMD%"=="new" goto passthrough
if /i "%CMD%"=="duplicate" goto passthrough
if /i "%CMD%"=="copy" goto passthrough
if /i "%CMD%"=="status" goto passthrough
if /i "%CMD%"=="restore" goto passthrough
if /i "%CMD%"=="help" goto passthrough
lune run tools/map.luau convert %*
exit /b %ERRORLEVEL%
:passthrough
lune run tools/map.luau %*
exit /b %ERRORLEVEL%
