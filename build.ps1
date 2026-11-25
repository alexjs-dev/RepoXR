# Builds both DLLs from source. Needs the .NET SDK 10.0 and R.E.P.O. v0.5.4.
#
#   .\build.ps1             build, and compare the result with the published hashes in dist\SHA256SUMS
#   .\build.ps1 -Publish    build, and put the DLLs and their hashes into dist\
param(
    [string]$GamePath,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
$names = 'RepoXR.dll', 'RepoXR.Preload.dll'

if (-not $GamePath) {
    $roots = @()
    foreach ($key in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam') {
        $steam = Get-ItemProperty $key -ErrorAction SilentlyContinue
        foreach ($path in $steam.SteamPath, $steam.InstallPath) { if ($path) { $roots += $path } }
    }
    foreach ($steamRoot in @($roots)) {
        $vdf = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($match in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                $roots += $match.Groups[1].Value.Replace('\\', '\')
            }
        }
    }
    $GamePath = $roots | ForEach-Object { Join-Path $_ 'steamapps\common\REPO' } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_ 'REPO.exe') } | Select-Object -First 1
}
if (-not $GamePath) { $GamePath = (Read-Host 'R.E.P.O. was not found. Path of the folder with REPO.exe').Trim().Trim('"') }
if (-not $GamePath -or -not (Test-Path -LiteralPath (Join-Path $GamePath 'REPO.exe'))) { throw "REPO.exe was not found in '$GamePath'. Use -GamePath." }

# The commit is part of the DLL: the published hashes can only be reproduced with the commit they were built from
$info = Join-Path $dist 'BUILD.txt'
if ($Publish) { $commit = (& git -C $root rev-parse HEAD).Trim() }
elseif (Test-Path -LiteralPath $info) { $commit = [regex]::Match([IO.File]::ReadAllText($info), '(?m)^commit: ([0-9a-f]{40})').Groups[1].Value }
else { $commit = '0' * 40 }

$output = Join-Path $root 'bin\Release\netstandard2.1'
foreach ($name in $names) { Remove-Item -LiteralPath (Join-Path $output $name) -ErrorAction SilentlyContinue }

& dotnet build (Join-Path $root 'RepoXR.sln') -c Release --no-incremental -nologo -v quiet -clp:NoSummary `
    -p:WarningLevel=0 -p:USE_TESTER=true "-p:TesterGamePath=$GamePath" `
    -p:Deterministic=true -p:DebugType=none -p:DebugSymbols=false "-p:PathMap=$root=/_" `
    -p:EnableSourceControlManagerQueries=false "-p:SourceRevisionId=$commit"
if ($LASTEXITCODE -ne 0) { throw 'The build failed. It needs the .NET SDK 10.0 and R.E.P.O. v0.5.4.' }

$built = foreach ($name in $names) {
    $path = Join-Path $output $name
    if (-not (Test-Path -LiteralPath $path)) { throw "$name was not built" }
    [pscustomobject]@{ Name = $name; Path = $path; Hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
}

if ($Publish) {
    [IO.Directory]::CreateDirectory($dist) | Out-Null
    $built | ForEach-Object { Copy-Item -LiteralPath $_.Path -Destination $dist -Force }
    [IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS'), (($built | ForEach-Object { "$($_.Hash) *$($_.Name)`n" }) -join ''))
    [IO.File]::WriteAllText($info, "RepoXR 1.2.3 for R.E.P.O. v0.5.4`ncommit: $commit`nsdk: $((& dotnet --version).Trim())`n")
    Write-Host "Published to ${dist}:"
    $built | ForEach-Object { Write-Host "  $($_.Hash)  $($_.Name)" }
    return
}

$sums = Join-Path $dist 'SHA256SUMS'
$published = if (Test-Path -LiteralPath $sums) { [IO.File]::ReadAllText($sums) } else { '' }
foreach ($file in $built) {
    $same = $published -match "(?m)^$($file.Hash) [ *]$([regex]::Escape($file.Name))\s*$"
    Write-Host ("  {0}  {1}  {2}" -f $file.Hash, $file.Name, $(if ($same) { 'SAME as published' } else { 'DIFFERENT from published' })) `
        -ForegroundColor $(if ($same) { 'Green' } else { 'Yellow' })
}
Write-Host "Built in $output"
Write-Host 'Different hashes are expected if you changed the source, or use another SDK or game version than in dist\BUILD.txt.'
