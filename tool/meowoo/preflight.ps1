param(
    [string]$Flutter = 'flutter',
    [string]$Go = 'go',
    [string]$AndroidSdk = $env:ANDROID_HOME
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'upstream.lock.json') -Raw | ConvertFrom-Json
$checks = [System.Collections.Generic.List[object]]::new()
function Check([string]$Name, [bool]$Passed, [string]$Detail) {
    $checks.Add([pscustomobject]@{ name = $Name; passed = $Passed; detail = $Detail })
}

Push-Location $root
try {
    $ancestor = & git merge-base --is-ancestor $lock.client.commit HEAD 2>$null
    Check 'client-baseline' ($LASTEXITCODE -eq 0) $lock.client.commit
    $coreDir = Join-Path $root $lock.core.path
    if (Test-Path -LiteralPath (Join-Path $coreDir '.git')) {
        $core = (& git -C $coreDir rev-parse HEAD).Trim()
        Check 'core-pin' ($core -eq $lock.core.commit) $core
    } else {
        Check 'core-pin' $false 'Run git submodule update --init --recursive.'
    }
    foreach ($entry in @(
        @('client-license', 'LICENSE', 'GNU GENERAL PUBLIC LICENSE'),
        @('core-license', ($lock.core.path + '/LICENSE'), 'GNU AFFERO GENERAL PUBLIC LICENSE')
    )) {
        $p = Join-Path $root $entry[1]
        $ok = (Test-Path -LiteralPath $p) -and ((Get-Content -LiteralPath $p -Raw) -match $entry[2])
        Check $entry[0] $ok $entry[1]
    }
    try {
        $v = (& $Flutter --version --machine 2>$null | Out-String | ConvertFrom-Json).frameworkVersion
        Check 'flutter' ($LASTEXITCODE -eq 0 -and $v -eq $lock.toolchain.flutter) "found=$v; expected=$($lock.toolchain.flutter)"
    } catch { Check 'flutter' $false "Not available: $Flutter" }
    try {
        $v = (& $Go version 2>$null | Out-String).Trim()
        Check 'go' ($LASTEXITCODE -eq 0 -and $v -match ('go' + [regex]::Escape($lock.toolchain.go) + '(\s|$)')) "found=$v; expected=$($lock.toolchain.go)"
    } catch { Check 'go' $false "Not available: $Go; expected=$($lock.toolchain.go)" }
    if (!$AndroidSdk) { $AndroidSdk = $env:ANDROID_SDK_ROOT }
    if ($AndroidSdk) {
        foreach ($p in @("platforms/android-$($lock.toolchain.androidCompileSdk)/android.jar", "ndk/$($lock.toolchain.androidNdk)/source.properties")) {
            Check "android:$p" (Test-Path -LiteralPath (Join-Path $AndroidSdk $p)) $p
        }
    } else { Check 'android-sdk' $false 'Set ANDROID_HOME or pass -AndroidSdk.' }
    $checks | ConvertTo-Json -Depth 4
    if ($checks.passed -contains $false) { exit 1 }
    exit 0
} finally { Pop-Location }
