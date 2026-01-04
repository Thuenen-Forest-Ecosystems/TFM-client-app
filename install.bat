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

:: Find certificate file
for %%F in (*.cer) do set CER_FILE=%%F

if not defined CER_FILE (
    echo WARNING: No .cer certificate file found.
    echo Attempting to extract from MSIX signature...
    echo.
    echo [1/2] Installing certificate...
    
    :: Extract and install certificate from MSIX
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$cert = (Get-AuthenticodeSignature '%MSIX_FILE%').SignerCertificate; ^
         if ($cert) { ^
             $store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root','LocalMachine'); ^
             $store.Open('ReadWrite'); ^
             $store.Add($cert); ^
             $store.Close(); ^
             Write-Host 'Certificate installed successfully' -ForegroundColor Green ^
         } else { ^
             Write-Host 'ERROR: Could not extract certificate from MSIX' -ForegroundColor Red; ^
             exit 1 ^
         }"
    
    if %errorLevel% neq 0 (
        echo ERROR: Certificate installation failed!
        pause
        exit /b 1
    )
) else (
    echo Found certificate: %CER_FILE%
    echo.
    echo [1/2] Installing certificate...
    
    :: Install certificate from .cer file
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Import-Certificate -FilePath '%CER_FILE%' -CertStoreLocation 'Cert:\LocalMachine\Root'"
    
    if %errorLevel% neq 0 (
        echo ERROR: Certificate installation failed!
        pause
        exit /b 1
    )
    
    echo Certificate installed successfully.
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
