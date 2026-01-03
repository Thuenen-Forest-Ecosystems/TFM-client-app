# Windows SSL Certificate Fix for PowerSync
# This script downloads and installs the SSL certificate from ci.thuenen.de
# Run this as Administrator to install the certificate system-wide

Write-Host "PowerSync Windows SSL Certificate Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$url = "https://ci.thuenen.de"
$certOutputPath = "$env:TEMP\ci_thuenen_cert.cer"

Write-Host "`nDownloading certificate from $url..." -ForegroundColor Yellow

try {
    # Download the certificate
    $webRequest = [Net.WebRequest]::Create($url)
    $webRequest.Timeout = 10000
    
    try {
        $response = $webRequest.GetResponse()
    } catch [System.Net.WebException] {
        # Expected to fail, but we can get the certificate from the exception
        if ($_.Exception.InnerException -and $_.Exception.InnerException.Certificate) {
            $cert = $_.Exception.InnerException.Certificate
            $bytes = $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
            [System.IO.File]::WriteAllBytes($certOutputPath, $bytes)
            
            Write-Host "✓ Certificate downloaded to: $certOutputPath" -ForegroundColor Green
            
            # Try to install it
            Write-Host "`nAttempting to install certificate..." -ForegroundColor Yellow
            Write-Host "Note: You may need to run this script as Administrator" -ForegroundColor Yellow
            
            $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certOutputPath)
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
            $store.Open("ReadWrite")
            $store.Add($cert2)
            $store.Close()
            
            Write-Host "✓ Certificate installed successfully!" -ForegroundColor Green
            Write-Host "`nYou can now restart your Flutter app and PowerSync should work." -ForegroundColor Green
            
            return
        }
    }
    
    # If we got here with no exception, try another method
    $tcpClient = New-Object System.Net.Sockets.TcpClient($url.Replace("https://", ""), 443)
    $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, {$true})
    $sslStream.AuthenticateAsClient($url.Replace("https://", ""))
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($sslStream.RemoteCertificate)
    $tcpClient.Close()
    
    $bytes = $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    [System.IO.File]::WriteAllBytes($certOutputPath, $bytes)
    
    Write-Host "✓ Certificate downloaded" -ForegroundColor Green
    
    # Install the certificate
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "CurrentUser")
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()
    
    Write-Host "✓ Certificate installed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nAlternative solution:" -ForegroundColor Yellow
    Write-Host "1. Open the URL in your browser: $url" -ForegroundColor White
    Write-Host "2. Click the padlock icon in the address bar" -ForegroundColor White
    Write-Host "3. View certificate details" -ForegroundColor White
    Write-Host "4. Export and install the certificate to 'Trusted Root Certification Authorities'" -ForegroundColor White
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
