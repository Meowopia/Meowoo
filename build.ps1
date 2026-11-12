param(
    [ValidateSet('Debug', 'Release', 'Check')][string]$Task = 'Debug',
    [switch]$UseMirror
)
$ErrorActionPreference = 'Stop'
$savedJava = $env:JAVA_HOME
$savedCache = $env:GRADLE_USER_HOME
try {
    Push-Location $PSScriptRoot
    if (-not $env:JAVA_HOME) {
        $javaExecutable = (Get-Command java -ErrorAction Stop).Source
        $env:JAVA_HOME = Split-Path -Parent (Split-Path -Parent $javaExecutable)
    }
    $bundledGradle = Join-Path $PSScriptRoot '.local-tools/gradle-9.1.0/bin/gradle.bat'
    $gradleCommand = if (Test-Path -LiteralPath $bundledGradle) { $bundledGradle } else { Join-Path $PSScriptRoot 'gradlew.bat' }
    if (Test-Path -LiteralPath '.local-tools/gradle-cache') {
        $env:GRADLE_USER_HOME = Join-Path $PSScriptRoot '.local-tools/gradle-cache'
    }
    $buildArguments = @('--console=plain', '--no-daemon')
    if ($UseMirror) { $buildArguments += @('-I', (Join-Path $PSScriptRoot 'scripts/mirrors.init.gradle')) }
    $buildArguments += switch ($Task) {
        'Check' { @(':app:testHandheldDebugUnitTest', ':app:testTvDebugUnitTest', ':app:lintHandheldDebug', ':app:lintTvDebug') }
        'Release' { @(':app:assembleHandheldRelease', ':app:assembleTvRelease') }
        default { @(':app:assembleHandheldDebug', ':app:assembleTvDebug') }
    }
    & $gradleCommand @buildArguments
    $result = $LASTEXITCODE
} finally {
    Pop-Location
    $env:JAVA_HOME = $savedJava
    $env:GRADLE_USER_HOME = $savedCache
}
exit $result
