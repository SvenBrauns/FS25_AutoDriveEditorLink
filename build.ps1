# Zips the mod into the game's mods folder. Entry names use "/" (Compress-Archive in
# Windows PowerShell 5.1 writes "\", and the game then does not find scripts/...).
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$mods = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "My Games\FarmingSimulator2025\mods"
$zip = Join-Path $mods "FS25_AutoDriveEditorLink.zip"
if (Test-Path $zip) { Remove-Item $zip }
$files = @("modDesc.xml", "icon_AutoDriveEditorLink.dds") + (Get-ChildItem "$PSScriptRoot\scripts" -Filter *.lua | ForEach-Object { "scripts/" + $_.Name })
$archive = [System.IO.Compression.ZipFile]::Open($zip, "Create")
foreach ($file in $files) {
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $PSScriptRoot $file), $file)
}
$archive.Dispose()
Write-Output "built $zip"
