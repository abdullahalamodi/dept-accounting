param([switch]$Installer)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
dart run build_runner build
if ($LASTEXITCODE -ne 0) { throw 'Model generation failed.' }
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows build failed.' }
$pubspec = Get-Content 'pubspec.yaml' -Raw
$match = [regex]::Match($pubspec, '(?m)^version:\s*([^+\s]+)')
$env:DUKAN_VERSION = $match.Groups[1].Value
New-Item -ItemType Directory -Force -Path 'build/distribution' | Out-Null
Compress-Archive -Path 'build/windows/x64/runner/Release/*' -DestinationPath "build/distribution/dukan-$env:DUKAN_VERSION-windows.zip" -Force
if ($Installer) {
    $iscc = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if (-not $iscc) { throw 'Install Inno Setup 6 and add ISCC.exe to PATH, then rerun with -Installer.' }
    & $iscc.Source 'installer/dukan.iss'
    if ($LASTEXITCODE -ne 0) { throw 'Installer build failed.' }
}
