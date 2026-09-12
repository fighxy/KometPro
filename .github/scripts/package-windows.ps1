$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$bundle = Join-Path $repoRoot 'build/windows/x64/runner/Release'
$dist = Join-Path $repoRoot 'dist'
$packaging = Join-Path $repoRoot 'build/windows-packaging'
New-Item -ItemType Directory -Force $dist, $packaging | Out-Null

$versionMatch = [regex]::Match((Get-Content (Join-Path $repoRoot 'pubspec.yaml') -Raw), '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$')
if (-not $versionMatch.Success) { throw 'Expected pubspec version MAJOR.MINOR.PATCH+BUILD' }
$version = $versionMatch.Groups[1].Value
foreach ($required in @('Komet.exe', 'flutter_windows.dll', 'opus.dll', 'rlottie.dll', 'data/icudtl.dat', 'data/app.so', 'data/flutter_assets')) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundle $required))) { throw "Missing bundle entry: $required" }
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsPath = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or -not $vsPath) { throw 'Visual C++ toolchain not found' }
$redistVersions = Get-ChildItem (Join-Path $vsPath 'VC/Redist/MSVC') -Directory |
    Where-Object Name -Match '^\d+\.\d+\.\d+$' | Sort-Object { [version]$_.Name } -Descending
$crt = $redistVersions | ForEach-Object {
    Get-ChildItem (Join-Path $_.FullName 'x64') -Directory -Filter 'Microsoft.VC*.CRT' -ErrorAction SilentlyContinue
} | Select-Object -First 1
if (-not $crt) { throw 'Redistributable x64 CRT not found' }
Copy-Item (Join-Path $crt.FullName '*.dll') -Destination $bundle -Force
foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    if (-not (Test-Path (Join-Path $bundle $dll))) { throw "Missing CRT: $dll" }
}
Copy-Item (Join-Path $repoRoot 'LICENSE') -Destination $bundle -Force
Copy-Item (Join-Path $repoRoot 'windows/opus/opus_license.txt') -Destination $bundle -Force

$innoVersion = '6.7.3'
$innoInstaller = Join-Path $packaging "innosetup-$innoVersion.exe"
Invoke-WebRequest "https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-$innoVersion.exe" -OutFile $innoInstaller
$expectedHash = '9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732'
if ((Get-FileHash $innoInstaller -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Inno Setup checksum mismatch' }
$innoDir = Join-Path $packaging 'inno'
$installerProcess = Start-Process -FilePath $innoInstaller -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/DIR=`"$innoDir`"") -WindowStyle Hidden -Wait -PassThru
if ($installerProcess.ExitCode -ne 0) { throw "Inno Setup installation failed: $($installerProcess.ExitCode)" }

$webview = Join-Path $packaging 'MicrosoftEdgeWebview2Setup.exe'
Invoke-WebRequest 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $webview
$signature = Get-AuthenticodeSignature -LiteralPath $webview
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
    throw 'WebView2 bootstrapper signature verification failed'
}

& (Join-Path $innoDir 'ISCC.exe') "/DAppVersion=$version" "/DBundleDir=$bundle" "/DOutputPath=$dist" "/DWebViewBootstrapper=$webview" (Join-Path $repoRoot 'windows/installer/kometpro.iss')
if ($LASTEXITCODE -ne 0) { throw "Installer compilation failed: $LASTEXITCODE" }
$setup = Join-Path $dist "KometPro-$version-windows-x64-setup.exe"
if (-not (Test-Path $setup) -or (Get-Item $setup).Length -eq 0) { throw 'Installer output is missing or empty' }
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath (Join-Path $dist 'Komet-windows-x64.zip') -Force
Get-ChildItem $dist -File | Where-Object Extension -In '.exe', '.zip' | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($_.Name)"
} | Set-Content (Join-Path $dist 'windows-sha256.txt') -Encoding utf8
