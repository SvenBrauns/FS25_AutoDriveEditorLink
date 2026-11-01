# Zips the mod into the game's mods folder.
$mods = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "My Games\FarmingSimulator2025\mods"
$zip = Join-Path $mods "FS25_AutoDriveEditorLink.zip"
Compress-Archive -Path "$PSScriptRoot\modDesc.xml", "$PSScriptRoot\icon_AutoDriveEditorLink.dds", "$PSScriptRoot\scripts" -DestinationPath $zip -Force
Write-Output "built $zip"
