# Windows native build readiness only; never installs or changes system settings.
$ErrorActionPreference = 'Stop'
$locator = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft Visual Studio/Installer/vswhere.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$locator) {
    $command = Get-Command vswhere.exe -ErrorAction SilentlyContinue
    if ($command) { $locator = $command.Source }
}
if (!$locator) {
    [pscustomobject]@{ ready = $false; reason = 'Visual Studio C++ Build Tools not installed'; config = (Join-Path $PSScriptRoot 'windows-build-tools.vsconfig') } | ConvertTo-Json
    exit 1
}
$instance = (& $locator -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.CMake.Project -format json | Out-String | ConvertFrom-Json) | Select-Object -First 1
if (!$instance) {
    [pscustomobject]@{ ready = $false; reason = 'MSVC x64/x86 and CMake components are required'; config = (Join-Path $PSScriptRoot 'windows-build-tools.vsconfig') } | ConvertTo-Json
    exit 1
}
$compiler = Get-ChildItem -Path (Join-Path $instance.installationPath 'VC/Tools/MSVC/*/bin/Hostx64/x64/cl.exe') -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
$cmake = Join-Path $instance.installationPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
$kits = (Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows Kits/Installed Roots' -ErrorAction SilentlyContinue).KitsRoot10
$headers = if ($kits) { Get-ChildItem -Path (Join-Path $kits 'Include/*/um/Windows.h') -ErrorAction SilentlyContinue | Select-Object -First 1 }
$ready = [bool]($instance.isComplete -and $compiler -and (Test-Path -LiteralPath $cmake) -and $headers)
[pscustomobject]@{ ready = $ready; installation = $instance.installationPath; compiler = $compiler.FullName; cmake = $cmake; sdkHeaders = $headers.FullName } | ConvertTo-Json
if (!$ready) { exit 1 }
