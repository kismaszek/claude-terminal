@echo off
rem Claude Windows Terminal-inditok telepitese / frissitese (offline). Dupla kattintassal indithato.
where pwsh >nul 2>nul
if errorlevel 1 (
  echo PowerShell 7 ^(pwsh^) szukseges. Telepites: winget install Microsoft.PowerShell
  pause
  exit /b 1
)
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
