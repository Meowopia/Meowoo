param(
    [Parameter(Mandatory)][string]$Apk,
    [Parameter(Mandatory)][string]$AndroidSdk,
    [string]$Version = '0.1.0',
    [int]$BuildNumber = 1,
    [switch]$Unsigned,
    [switch]$AllowDebugCertificate
)
$ErrorActionPreference = 'Stop'
$apkPath = (Resolve-Path -LiteralPath $Apk).Path
$buildTools = Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'build-tools') -Directory |
    Where-Object { (Test-Path -LiteralPath (Join-Path $_.FullName 'aapt.exe')) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'aapt2.exe')) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat')) } |
    Sort-Object Name -Descending | Select-Object -First 1
if (!$buildTools) { throw 'Android build-tools must include aapt and apksigner.' }
$badging = (& (Join-Path $buildTools.FullName 'aapt.exe') dump badging $apkPath 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw 'aapt could not read the APK.' }
$v = [regex]::Escape($Version)
if ($badging -notmatch "(?m)^package: name='com\.meowopia\.meowoo' versionCode='$BuildNumber' versionName='$v'") { throw 'Unexpected APK product identity or version.' }
if ($badging -notmatch "(?m)^sdkVersion:'28'" -or $badging -notmatch "(?m)^launchable-activity: name='miru\.alpha\.MainActivity'") { throw 'Unexpected phone SDK minimum or missing launcher activity.' }
if ($badging -notmatch "(?m)^native-code: 'arm64-v8a'\s*\r?$") { throw 'APK is not restricted to ARM64.' }
$icon = [regex]::Match($badging, "(?m)^application: label='Meowoo' icon='([^']+)'").Groups[1].Value
if (!$icon) { throw 'Meowoo application label or icon not present.' }
$resources = (& (Join-Path $buildTools.FullName 'aapt2.exe') dump resources $apkPath 2>&1 | Out-String)
$resourceIcon = [regex]::Match($resources, '(?m)^\s*resource [^\r\n]* drawable/meowoo_phone_logo\s*\r?\n[ \t]+\(nodpi\) \(file\) (\S+)').Groups[1].Value
if ($LASTEXITCODE -ne 0 -or $resourceIcon -ne $icon) { throw 'APK launcher does not use the Meowoo logo.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($apkPath)
try {
    $required = @('classes.dex','lib/arm64-v8a/libapp.so','lib/arm64-v8a/libflutter.so','lib/arm64-v8a/libmiru_core.so','lib/arm64-v8a/libffmpeg_merge.so','assets/flutter_assets/assets/bundled_sources/meowoo.open-films.js',$icon)
    foreach ($name in $required) {
        $entry = $archive.GetEntry($name)
        if (!$entry -or !$entry.Length) { throw "Required APK file missing or empty: $name" }
    }
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -match '^lib/(?!arm64-v8a/)[^/]+/.+\.so$') { throw "Unexpected ABI: $($entry.FullName)" }
    }
} finally { $archive.Dispose() }
$previousNativePreference=$PSNativeCommandUseErrorActionPreference
try {
    $PSNativeCommandUseErrorActionPreference=$false
    $signature = (& (Join-Path $buildTools.FullName 'apksigner.bat') verify --print-certs $apkPath 2>&1 | Out-String)
    $sigExit = $LASTEXITCODE
} finally { $PSNativeCommandUseErrorActionPreference=$previousNativePreference }
$cert = $null
if ($Unsigned) {
    if ($sigExit -eq 0 -or $signature -notmatch '(?i)missing META-INF/MANIFEST\.MF|no signatures|no JAR signatures') { throw 'Expected a structurally valid, unsigned APK.' }
} else {
    if ($sigExit -ne 0) { throw 'APK signature verification failed.' }
    if (!$AllowDebugCertificate -and $signature -match '(?i)certificate DN:.*CN=Android Debug') { throw 'A debug certificate is not allowed for a formal APK.' }
    $cert = [regex]::Match($signature, '(?im)certificate SHA-256 digest:\s*([a-f0-9]{64})').Groups[1].Value
    if (!$cert) { throw 'APK signing fingerprint not available.' }
}
[pscustomobject]@{
    apk = $apkPath
    package = 'com.meowopia.meowoo'
    versionName = $Version
    versionCode = $BuildNumber
    minSdk = 28
    abi = 'arm64-v8a'
    bytes = (Get-Item -LiteralPath $apkPath).Length
    sha256 = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash.ToLowerInvariant()
    signed = !$Unsigned
    certificateSha256 = $cert
}
