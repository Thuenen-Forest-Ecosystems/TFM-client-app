# Install MSIX Certificate to Trusted Root
# Run as Administrator: Right-click → "Run with PowerShell"

param(
    [string]$MsixPath = ""
)

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click the script and select 'Run with PowerShell' or 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Find MSIX file
if ([string]::IsNullOrWhiteSpace($MsixPath)) {
    $MsixPath = Get-ChildItem -Path . -Filter "*.msix" | Select-Object -First 1 -ExpandProperty FullName
}

if ([string]::IsNullOrWhiteSpace($MsixPath) -or -not (Test-Path $MsixPath)) {
    Write-Host "ERROR: No MSIX file found in current directory" -ForegroundColor Red
    Write-Host "Please download the MSIX file first from GitHub releases" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Installing certificate from: $MsixPath" -ForegroundColor Cyan
Write-Host ""

try {
    # Extract certificate from MSIX
    $cert = (Get-AuthenticodeSignature $MsixPath).SignerCertificate
    
    if ($null -eq $cert) {
        throw "Could not extract certificate from MSIX"
    }
    
    Write-Host "Certificate Details:" -ForegroundColor Green
    Write-Host "  Subject: $($cert.Subject)"
    Write-Host "  Issuer: $($cert.Issuer)"
    Write-Host "  Thumbprint: $($cert.Thumbprint)"
    Write-Host "  Valid: $($cert.NotBefore) to $($cert.NotAfter)"
    Write-Host ""
    
    # Install to Trusted Root Certification Authorities
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()
    
    Write-Host "SUCCESS: Certificate installed to Trusted Root Certification Authorities" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now double-click the MSIX file to install the application" -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-Host "ERROR: Failed to install certificate - $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Read-Host "Press Enter to exit"
