@echo off
setlocal EnableDelayedExpansion

:: Get the directory where this script is located
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs -ArgumentList '-WorkingDirectory', '%SCRIPT_DIR%'"
    exit /b
)

echo ============================================
echo Terrestrial Forest Monitor - Installation
echo ============================================
echo.
echo Working directory: %CD%
echo.

:: Check and enable sideloading
echo Checking Windows sideloading settings...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'; ^
     if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }; ^
     Set-ItemProperty -Path $regPath -Name 'AllowAllTrustedApps' -Value 1 -Type DWord -Force; ^
     Write-Host 'Sideloading enabled' -ForegroundColor Green"

if %errorLevel% neq 0 (
    echo WARNING: Could not enable sideloading automatically
)

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
             $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root','LocalMachine'); ^
             $rootStore.Open('ReadWrite'); ^
             $rootStore.Add($cert); ^
             $rootStore.Close(); ^
             Write-Host 'Certificate added to Root store' -ForegroundColor Green; ^
             $peopleStore = New-Object System.Security.Cryptography.X509Certificates.X509Store('TrustedPeople','LocalMachine'); ^
             $peopleStore.Open('ReadWrite'); ^
             $peopleStore.Add($cert); ^
             $peopleStore.Close(); ^
             Write-Host 'Certificate added to TrustedPeople store' -ForegroundColor Green ^
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
    
    :: Install certificate to both Root and TrustedPeople stores
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Import-Certificate -FilePath '%CER_FILE%' -CertStoreLocation 'Cert:\LocalMachine\Root'; ^
         Import-Certificate -FilePath '%CER_FILE%' -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople'"
    
    if %errorLevel% neq 0 (
        echo ERROR: Certificate installation failed!
        pause
        exit /b 1
    )
    
    echo Certificate installed successfully to Root and TrustedPeople stores.
)

echo.
echo [2/2] Installing application...
echo.

:: Install MSIX
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Set-Location '%SCRIPT_DIR%'; Add-AppxPackage -Path '%MSIX_FILE%'"

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
    echo ============================================
    echo FEHLER: Installation fehlgeschlagen!
    echo ============================================
    echo.
    echo Falls Zertifikatfehler angezeigt wird:
    echo.
    echo Windows 11:
    echo   Einstellungen -^> Datenschutz und Sicherheit -^> Fuer Entwickler
    echo   -^> "Entwicklermodus" ODER "Apps querladen" aktivieren
    echo.
    echo Windows 10:
    echo   Einstellungen -^> Update und Sicherheit -^> Fuer Entwickler
    echo   -^> "Entwicklermodus" ODER "Apps querladen" aktivieren
    echo.
    echo Dann diesen Installer erneut ausfuehren.
    echo.
    echo Alternative: Portable ZIP-Version verwenden
    echo (keine Installation oder Zertifikat erforderlich)
    echo.
)

pause
