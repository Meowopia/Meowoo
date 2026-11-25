param([string]$Dart = 'dart')

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$parent = Join-Path $root '.local-tools'
$directory = Join-Path $parent ('jellyfin-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$certificatePath = Join-Path $directory 'cert.pem'
$keyPath = Join-Path $directory 'key.pem'
$key = $null
$certificate = $null
$exitCode = 1
Push-Location $root
try {
    # Temporary trust belongs to the Dart fixture only, not the OS or app.
    $key = [Security.Cryptography.RSA]::Create(2048)
    $request = [Security.Cryptography.X509Certificates.CertificateRequest]::new(
        'CN=Meowoo local test', $key,
        [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $san = [Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
    $san.AddIpAddress([Net.IPAddress]::Loopback)
    $san.AddDnsName('localhost')
    $request.CertificateExtensions.Add($san.Build())
    $request.CertificateExtensions.Add(
        [Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new(
            $false, $false, 0, $true
        )
    )
    $certificate = $request.CreateSelfSigned(
        [DateTimeOffset]::UtcNow.AddMinutes(-1), [DateTimeOffset]::UtcNow.AddDays(1)
    )
    [IO.File]::WriteAllText($certificatePath, $certificate.ExportCertificatePem())
    [IO.File]::WriteAllText($keyPath, $key.ExportPkcs8PrivateKeyPem())
    & $Dart tool/meowoo/check_jellyfin.dart $certificatePath $keyPath
    $exitCode = $LASTEXITCODE
} finally {
    if ($certificate) { $certificate.Dispose() }
    if ($key) { $key.Dispose() }
    Pop-Location
    # Exact file cleanup only; never recursively remove a computed directory.
    foreach ($file in @($certificatePath, $keyPath)) {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
    }
    [IO.Directory]::Delete($directory)
}
exit $exitCode
