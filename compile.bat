@echo off
setlocal

echo ========================================
echo KTPAdminAudit Plugin Compiler
echo Using KTPAMXX 2.0
echo ========================================
echo.

:: Set compiler path
set "COMPILER=N:\Nein_\KTP\amxmodx_2_0"
set "AMXXPC=%COMPILER%\amxxpc.exe"
set "INCLUDE=%COMPILER%\include"

:: Check if compiler exists
if not exist "%AMXXPC%" (
    echo ERROR: Compiler not found at %AMXXPC%
    echo Please ensure KTPAMXX 2.0 is built and collected.
    pause
    exit /b 1
)

:: Output directory
set "OUTPUT=%~dp0compiled"
if not exist "%OUTPUT%" mkdir "%OUTPUT%"

echo Compiling KTPAdminAudit.sma...
echo.

:: Compile the plugin
"%AMXXPC%" "%~dp0KTPAdminAudit.sma" -i"%INCLUDE%" -o"%OUTPUT%\KTPAdminAudit.amxx"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo BUILD SUCCESSFUL!
    echo ========================================
    echo Output: %OUTPUT%\KTPAdminAudit.amxx
    echo.
    echo Copying to staging folder...
    set "STAGING=N:\Nein_\KTP DoD Server\dod\addons\ktpamx\plugins"
    copy /Y "%OUTPUT%\KTPAdminAudit.amxx" "%STAGING%\KTPAdminAudit.amxx"
    if %ERRORLEVEL% EQU 0 (
        echo Staged: %STAGING%\KTPAdminAudit.amxx
    ) else (
        echo WARNING: Failed to copy to staging folder
    )
) else (
    echo.
    echo ========================================
    echo BUILD FAILED!
    echo ========================================
    echo Check the errors above.
)

echo.
pause
