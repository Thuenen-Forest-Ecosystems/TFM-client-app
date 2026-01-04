@echo off
setlocal EnableDelayedExpansion

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================
echo Terrestrial Forest Monitor - Installation
echo ============================================
echo.

:: Find MSIX file
for %%F in (*.msix) do set MSIX_FILE=%%F

if not defined MSIX_FILE (
    echo ERROR: No MSIX file found!
    echo Please download the MSIX file first.
    pause
    exit /b 1
)

echo Found: %MSIX_FILE%
echo.
echo [1/2] Installing certificate...

:: Extract and install certificate
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$cert = (Get-AuthenticodeSignature '%MSIX_FILE%').SignerCertificate; ^
     if ($cert) { ^
         $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root','LocalMachine'); ^
         $store.Open('ReadWrite'); ^
         $store.Add($cert); ^
         $store.Close(); ^
         Write-Host 'Certificate installed successfully' -ForegroundColor Green ^
     } else { ^
         Write-Host 'ERROR: Could not extract certificate' -ForegroundColor Red; ^
         exit 1 ^
     }"

if %errorLevel% neq 0 (
    echo ERROR: Certificate installation failed!
    pause
    exit /b 1
)

echo.
echo [2/2] Installing application...
echo.

:: Install MSIX
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Add-AppxPackage -Path '%MSIX_FILE%'"

if %errorLevel% equ 0 (
    echo.
    echo ============================================
    echo SUCCESS! Application installed.
    echo ============================================
    echo.
    echo You can now start the app from the Start Menu.
    echo.
) else (
    echo.
    echo ERROR: Installation failed!
    echo.
)

pause
