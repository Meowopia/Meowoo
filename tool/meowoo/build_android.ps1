param(
    [string]$Flutter = 'flutter',
    [string]$Go = 'go',
    [string]$AndroidSdk = $env:ANDROID_HOME,
    [string]$JavaHome = $env:JAVA_HOME,
    [string]$Version = '0.1.0',
    [ValidateSet('Debug','Release')][string]$Configuration = 'Release',
    [int]$BuildNumber = 1,
    [switch]$UseSystemProxy
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$oldPath = $env:PATH
$oldJava = $env:JAVA_HOME
$oldAndroid = $env:ANDROID_HOME
$oldAndroidRoot = $env:ANDROID_SDK_ROOT
$oldGradleOpts = $env:GRADLE_OPTS
$oldHttpsProxy = $env:HTTPS_PROXY
$oldHttpProxy = $env:HTTP_PROXY
$oldArm64 = $env:ORG_GRADLE_PROJECT_meowooPhoneArm64
$oldUnsigned = $env:ORG_GRADLE_PROJECT_meowooUnsignedPhoneAssembly
$oldFlutterAbi = [Environment]::GetEnvironmentVariable("ORG_GRADLE_PROJECT_disable-abi-filtering", "Process")
$oldIncremental = [Environment]::GetEnvironmentVariable("ORG_GRADLE_PROJECT_kotlin.incremental", "Process")
Push-Location $root
try {
    if (!$AndroidSdk) { $AndroidSdk = $env:ANDROID_SDK_ROOT }
    if (!$AndroidSdk -or !(Test-Path -LiteralPath (Join-Path $AndroidSdk 'platforms/android-36/android.jar'))) {
        throw 'Android SDK 36 is required. Pass -AndroidSdk or set ANDROID_HOME.'
    }
    if (!$JavaHome -or !(Test-Path -LiteralPath (Join-Path $JavaHome 'bin/java.exe'))) {
        throw 'Pass a valid -JavaHome or set JAVA_HOME.'
    }
    $goCommand = Get-Command $Go -ErrorAction Stop
    $env:PATH = (Split-Path $goCommand.Source) + ';' + (Join-Path $JavaHome 'bin') + ';' + $oldPath
    $env:JAVA_HOME = $JavaHome
    $env:ANDROID_HOME = $AndroidSdk
    $env:ANDROID_SDK_ROOT = $AndroidSdk
    $env:GRADLE_OPTS = "$oldGradleOpts -Dorg.gradle.internal.http.connectionTimeout=15000 -Dorg.gradle.internal.http.socketTimeout=20000"
    if ($UseSystemProxy) {
        $target = [uri]'https://dl.google.com'
        $proxy = [System.Net.WebRequest]::DefaultWebProxy.GetProxy($target)
        if ($proxy.Host -ne $target.Host) {
            if ($proxy.UserInfo) { throw 'Credential-bearing proxy URLs are not accepted by this script.' }
            $env:HTTPS_PROXY = $proxy.AbsoluteUri
            $env:HTTP_PROXY = $proxy.AbsoluteUri
            $env:GRADLE_OPTS += " -Dhttps.proxyHost=$($proxy.Host) -Dhttps.proxyPort=$($proxy.Port) -Dhttp.proxyHost=$($proxy.Host) -Dhttp.proxyPort=$($proxy.Port)"
        }
    }
    $env:ORG_GRADLE_PROJECT_meowooPhoneArm64 = 'true'
    [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_disable-abi-filtering', 'true', 'Process')
    $env:ORG_GRADLE_PROJECT_meowooUnsignedPhoneAssembly = 'false'
    # Projects and Pub cache can reside on different Windows drives.
    [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.incremental', 'false', 'Process')
    $mode = $Configuration.ToLowerInvariant()
    if ($Configuration -eq 'Release' -and !(Test-Path -LiteralPath 'android/key.properties') -and !($env:KEYSTORE -and $env:KEYSTORE_PASSWORD -and $env:KEY_ALIAS -and $env:KEY_PASSWORD)) {
        throw 'Formal release requires a configured signing key. No key will be created and debug signing is not a fallback.'
    }
    $artifactDir = Join-Path $root '.local-tools/artifacts/android'
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
    $log = Join-Path $artifactDir 'build.log'
    Write-Output 'Building Meowoo Android arm64; no install, signing-key creation or publishing.'
    & $Flutter build apk "--$mode" --no-pub --target-platform android-arm64 --build-name $Version --build-number $BuildNumber *> $log
    if ($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $log -Tail 45
        throw "Android build failed. Full log: $log"
    }
    $apk = Join-Path $root "build/app/outputs/flutter-apk/app-$mode.apk"
    if (!(Test-Path -LiteralPath $apk)) { throw 'Build returned success without the expected APK.' }
    $verification = & (Join-Path $PSScriptRoot 'check_android_phone_apk.ps1') -Apk $apk -AndroidSdk $AndroidSdk -Version $Version -BuildNumber $BuildNumber -AllowDebugCertificate:($Configuration -eq 'Debug')
    $out = Join-Path $artifactDir "Meowoo-$Version-android-arm64-$mode.apk"
    Copy-Item -LiteralPath $apk -Destination $out -Force
    $receipt = [ordered]@{
        artifact = $out
        sha256 = (Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash.ToLowerInvariant()
        bytes = (Get-Item -LiteralPath $out).Length
        package = 'com.meowopia.meowoo'
        mode = $mode
        certificateSha256 = $verification.certificateSha256
        deliveryApproved = $false
        deviceTested = $false
        published = $false
    }
    $receipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifactDir 'receipt.json') -Encoding UTF8
    $receipt | ConvertTo-Json
} finally {
    $env:PATH = $oldPath
    $env:JAVA_HOME = $oldJava
    $env:ANDROID_HOME = $oldAndroid
    $env:ANDROID_SDK_ROOT = $oldAndroidRoot
    $env:GRADLE_OPTS = $oldGradleOpts
    $env:HTTPS_PROXY = $oldHttpsProxy
    $env:HTTP_PROXY = $oldHttpProxy
    [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_disable-abi-filtering', $oldFlutterAbi, 'Process')
    $env:ORG_GRADLE_PROJECT_meowooPhoneArm64 = $oldArm64
    $env:ORG_GRADLE_PROJECT_meowooUnsignedPhoneAssembly = $oldUnsigned
    [Environment]::SetEnvironmentVariable('ORG_GRADLE_PROJECT_kotlin.incremental', $oldIncremental, 'Process')
    Pop-Location
}
