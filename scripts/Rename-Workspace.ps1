[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceDirectory = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
$sourceItem = Get-Item -LiteralPath $SourceDirectory
if (-not $sourceItem.PSIsContainer -or ($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Source must be a real directory, not a file or junction.'
}
$sourcePath = $sourceItem.FullName.TrimEnd('\')
$parentPath = Split-Path -Parent $sourcePath
if ((Split-Path -Leaf $sourcePath) -eq 'Meowoo') {
    Write-Output "Already named Meowoo: $sourcePath"
    return
}
if ((Split-Path -Leaf $sourcePath) -ne 'HG' -or -not $parentPath) {
    throw 'This helper only renames the HG workspace to its sibling Meowoo.'
}
$destinationPath = [IO.Path]::GetFullPath((Join-Path $parentPath 'Meowoo'))
if ((Split-Path -Parent $destinationPath) -ne $parentPath) {
    throw 'Destination must remain in the same parent directory.'
}
if (Test-Path -LiteralPath $destinationPath) {
    throw "Destination already exists; nothing changed: $destinationPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'meowoo-android\Meowoo.md') -PathType Leaf)) {
    throw 'Expected Meowoo project document was not found; nothing changed.'
}

$oldConfigPath = Join-Path $sourcePath 'meowoo-android\local.properties'
$newConfigText = $null
if (Test-Path -LiteralPath $oldConfigPath -PathType Leaf) {
    $oldConfigText = [IO.File]::ReadAllText($oldConfigPath)
    $oldSdkPrefix = $sourcePath.Replace('\', '/').Replace(':', '\:') + '/'
    $newSdkPrefix = $destinationPath.Replace('\', '/').Replace(':', '\:') + '/'
    $newConfigText = $oldConfigText.Replace($oldSdkPrefix, $newSdkPrefix)
}

if ($PSCmdlet.ShouldProcess($sourcePath, "Rename workspace to $destinationPath and update local SDK path")) {
    # Leave the source directory before renaming it. Do not terminate other programs.
    Set-Location -LiteralPath $parentPath
    try {
        Rename-Item -LiteralPath $sourcePath -NewName 'Meowoo'
    } catch {
        throw "Rename failed; source files were not changed. Close programs using the workspace and retry. $($_.Exception.Message)"
    }
    if ($null -ne $newConfigText) {
        $newConfigPath = Join-Path $destinationPath 'meowoo-android\local.properties'
        try {
            [IO.File]::WriteAllText($newConfigPath, $newConfigText, [Text.UTF8Encoding]::new($false))
        } catch {
            throw "Workspace was renamed to $destinationPath, but local.properties could not be updated. Update its SDK path before building. $($_.Exception.Message)"
        }
    }
    Write-Output "Renamed workspace: $destinationPath"
    Write-Output "Open this directory again in Codex or your editor. Existing shortcuts may still point to HG."
}
