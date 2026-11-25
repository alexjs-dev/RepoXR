# Installs RepoXR for R.E.P.O. v0.5.4 with everything it needs: BepInExPack, FixPluginTypesSerialization, RepoXR 1.2.3 (VR
# libraries and assets) and the DLLs of this fork. Every file is checked against a SHA-256 hash. See README.md.
#
#   .\install.ps1                          r2modman (new profile "RepoXR-v0.5.4"), or the game folder without a mod manager
#   .\install.ps1 -ProfileName MyProfile   another profile (created if needed)
#   .\install.ps1 -Target Game             straight into the game folder
#   .\install.ps1 -Check                   only compare an installation with the published hashes
param(
    [ValidateSet('Auto', 'ModManager', 'Game')][string]$Target = 'Auto',
    [string]$ProfileName = 'RepoXR-v0.5.4',
    [string]$ProfilesPath,
    [string]$GamePath,
    [switch]$Check
)

$scriptRoot = $PSScriptRoot

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $gameVersion = 'v0.5.4'
    $distUrl = 'https://raw.githubusercontent.com/alexjs-dev/RepoXR/main/dist'
    $packages = @(
        @{ Owner = 'BepInEx'; Name = 'BepInExPack'; Version = '5.4.2305'
           Description = 'BepInEx pack for Mono Unity games. Preconfigured and ready to use.'; Dependencies = @()
           Hash = 'f99b6302b6bdca5bab26f275c261cca448b29bbac34eaa5cbebb42c4246fb244' },
        @{ Owner = 'DaXcess'; Name = 'FixPluginTypesSerialization'; Version = '1.1.3'
           Description = 'Fix custom Serializable structs and such not properly getting deserialized by Unity.'; Dependencies = @()
           Hash = '69ba3ab643a4e9a35db60451457d5e4945d4753cf5f416e509eaa5bea28563e2' },
        @{ Owner = 'DaXcess'; Name = 'RepoXR'; Version = '1.2.3'
           Description = 'Extracting Valuables in VR'
           Dependencies = @('BepInEx-BepInExPack-5.4.2305', 'DaXcess-FixPluginTypesSerialization-1.1.1')
           Hash = 'bc6459b97a7663d25059fc7d8c362bbd42d5159b12c5969ad1448a498f77f35e' }
    )

    function Write-Step([string]$Text) { Write-Host "==> $Text" -ForegroundColor Cyan }

    function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

    function Find-Game {
        $roots = @()
        foreach ($key in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam') {
            $steam = Get-ItemProperty $key -ErrorAction SilentlyContinue
            foreach ($path in $steam.SteamPath, $steam.InstallPath) { if ($path) { $roots += $path } }
        }
        foreach ($root in @($roots)) {
            $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
            if (Test-Path -LiteralPath $vdf) {
                foreach ($match in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
                    $roots += $match.Groups[1].Value.Replace('\\', '\')
                }
            }
        }
        foreach ($root in $roots) {
            $game = Join-Path $root 'steamapps\common\REPO'
            if (Test-Path -LiteralPath (Join-Path $game 'REPO.exe')) { return (Resolve-Path -LiteralPath $game).Path }
        }
    }

    function Get-GameVersion([string]$Path) {
        $file = Join-Path $Path 'REPO_Data\sharedassets0.assets'
        if (-not (Test-Path -LiteralPath $file)) { return $null }
        $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($file))
        $match = [regex]::Match($text, 'RELEASE (v\d+(\.\d+)+)')
        if ($match.Success) { $match.Groups[1].Value }
    }

    function Find-Profiles {
        foreach ($root in "$env:APPDATA\r2modmanPlus-local", "$env:APPDATA\Thunderstore Mod Manager\DataFolder") {
            if (Test-Path -LiteralPath $root) { return (Join-Path $root 'REPO\profiles') }
        }
    }

    # Where the files of a package go. Mod managers keep every package in its own folder
    function Get-Destination($Package, [string]$Entry, [string]$Root, [bool]$Managed) {
        $full = "$($Package.Owner)-$($Package.Name)"
        if ($Package.Name -eq 'BepInExPack') {
            if ($Entry -like 'BepInExPack/*') { return (Join-Path $Root $Entry.Substring(12)) }
            return $null
        }
        if ($Entry -match '^BepInEx/(plugins|patchers)/(.+)$') {
            if ($Managed) { return (Join-Path $Root "BepInEx\$($Matches[1])\$full\$($Matches[2])") }
            return (Join-Path $Root $Entry)
        }
        if ($Entry -like 'BepInEx/*') { return (Join-Path $Root $Entry) }
        if ($Managed) { return (Join-Path $Root "BepInEx\plugins\$full\$Entry") }
        return $null
    }

    function Install-Package($Package, [string]$Temp, [string]$Root, [bool]$Managed) {
        $full = "$($Package.Owner)-$($Package.Name)-$($Package.Version)"
        Write-Step "$full"
        $zip = Join-Path $Temp "$full.zip"
        Invoke-WebRequest -UseBasicParsing -OutFile $zip `
            -Uri "https://thunderstore.io/package/download/$($Package.Owner)/$($Package.Name)/$($Package.Version)/"
        if ((Get-Sha256 $zip) -ne $Package.Hash) { throw "The download of $full does not match its SHA-256 hash. Nothing of it was installed." }

        $base = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
        $archive = [IO.Compression.ZipFile]::OpenRead($zip)
        try {
            foreach ($entry in $archive.Entries) {
                $name = $entry.FullName.Replace('\', '/')
                if ($name.EndsWith('/')) { continue }
                $destination = Get-Destination $Package $name $Root $Managed
                if (-not $destination) { continue }
                $destination = [IO.Path]::GetFullPath($destination)
                if (-not $destination.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) { throw "Unexpected path in ${full}: $name" }
                # Keep the settings of the mod loader
                if ($destination -like '*\BepInEx.cfg' -and (Test-Path -LiteralPath $destination)) { continue }
                [IO.Directory]::CreateDirectory((Split-Path $destination)) | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
            }
        }
        finally { $archive.Dispose() }
    }

    # List the packages in the profile, so the mod manager shows them
    function Update-ModList([string]$Root) {
        $file = Join-Path $Root 'mods.yml'
        $text = ''
        if (Test-Path -LiteralPath $file) { $text = [IO.File]::ReadAllText($file).Replace("`r`n", "`n") }
        if ($text.Trim() -eq '[]') { $text = '' }
        if ($text -and -not $text.EndsWith("`n")) { $text += "`n" }
        $blocks = @([regex]::Split($text, '(?m)^(?=- manifestVersion:)') | Where-Object { $_.Trim() })
        $time = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

        foreach ($package in $packages) {
            $full = "$($package.Owner)-$($package.Name)"
            $blocks = @($blocks | Where-Object { $_ -notmatch "(?m)^  name: $([regex]::Escape($full))\s*$" })
            $version = $package.Version.Split('.')
            $dependencies = if ($package.Dependencies) { "`n" + (($package.Dependencies | ForEach-Object { "    - $_" }) -join "`n") } else { ' []' }
            $blocks += @"
- manifestVersion: 1
  name: $full
  authorName: $($package.Owner)
  websiteUrl: https://thunderstore.io/c/repo/p/$($package.Owner)/$($package.Name)/
  displayName: $($package.Name)
  description: '$($package.Description)'
  gameVersion: '0'
  networkMode: both
  packageType: other
  installMode: managed
  installedAtTime: $time
  loaders: []
  dependencies:$dependencies
  incompatibilities: []
  optionalDependencies: []
  versionNumber:
    major: $($version[0])
    minor: $($version[1])
    patch: $($version[2])
  enabled: true
  onlineSource: true
  trustedPackage: false

"@.Replace("`r`n", "`n").TrimEnd("`n") + "`n"
        }
        [IO.File]::WriteAllText($file, ($blocks -join ''))
    }

    # The published hashes: the dist folder next to this script, or the one on GitHub
    function Get-Published([string]$Temp) {
        $local = if ($scriptRoot) { Join-Path $scriptRoot 'dist' }
        if ($local -and (Test-Path -LiteralPath (Join-Path $local 'SHA256SUMS'))) { $folder = $local }
        else {
            $folder = Join-Path $Temp 'dist'
            [IO.Directory]::CreateDirectory($folder) | Out-Null
            foreach ($name in 'SHA256SUMS', 'RepoXR.dll', 'RepoXR.Preload.dll') {
                Invoke-WebRequest -UseBasicParsing -Uri "$distUrl/$name" -OutFile (Join-Path $folder $name)
            }
        }

        $files = @()
        foreach ($line in [IO.File]::ReadAllLines((Join-Path $folder 'SHA256SUMS'))) {
            if ($line -match '^([0-9a-f]{64}) [ *](.+)$') { $files += @{ Hash = $Matches[1]; Name = $Matches[2]; Source = (Join-Path $folder $Matches[2]) } }
        }
        foreach ($name in 'RepoXR.dll', 'RepoXR.Preload.dll') {
            if (-not ($files | Where-Object { $_.Name -eq $name })) { throw "SHA256SUMS does not list $name" }
        }
        foreach ($file in $files) {
            if ((Get-Sha256 $file.Source) -ne $file.Hash) { throw "$($file.Name) does not match SHA256SUMS. It is damaged or was modified." }
        }
        $files
    }

    function Get-InstallPath([string]$Name, [string]$Root, [bool]$Managed) {
        $kind = if ($Name -eq 'RepoXR.Preload.dll') { 'patchers' } else { 'plugins' }
        $folder = if ($Managed) { "BepInEx\$kind\DaXcess-RepoXR\RepoXR" } else { "BepInEx\$kind\RepoXR" }
        Join-Path $Root "$folder\$Name"
    }

    function Test-Installed($Files, [string]$Root, [bool]$Managed) {
        $ok = $true
        foreach ($file in $Files) {
            $path = Get-InstallPath $file.Name $Root $Managed
            if (-not (Test-Path -LiteralPath $path)) { Write-Host "    MISSING    $path" -ForegroundColor Red; $ok = $false; continue }
            if ((Get-Sha256 $path) -eq $file.Hash) { Write-Host "    OK         $($file.Name)  $($file.Hash)" -ForegroundColor Green }
            else { Write-Host "    DIFFERENT  $($file.Name)  $(Get-Sha256 $path)" -ForegroundColor Red; $ok = $false }
        }
        $ok
    }

    # --- Find out where to install

    if (-not $GamePath) { $GamePath = Find-Game }
    if (-not $ProfilesPath -and $Target -ne 'Game') { $ProfilesPath = Find-Profiles }
    if ($Target -eq 'ModManager' -and -not $ProfilesPath) { throw 'r2modman was not found. Start it once and select R.E.P.O., or use -ProfilesPath.' }

    $managed = $Target -ne 'Game' -and [bool]$ProfilesPath
    if ($managed) {
        if (-not $ProfileName -or $ProfileName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $ProfileName -match '^\.+$') { throw "'$ProfileName' is not a valid profile name" }
        $root = Join-Path $ProfilesPath $ProfileName
    }
    else { $root = $GamePath }
    if (-not $root) { throw 'R.E.P.O. was not found. Use -GamePath with the folder of REPO.exe.' }

    $temp = Join-Path ([IO.Path]::GetTempPath()) ('RepoXR-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($temp) | Out-Null
    try {
        Write-Step 'Checking the hashes of this build'
        $files = @(Get-Published $temp)

        if ($Check) {
            Write-Step "Comparing $root with the published build"
            if (Test-Installed $files $root $managed) { Write-Host 'The installed DLLs are the published build.' -ForegroundColor Green; return }
            throw 'The installed DLLs are not the published build.'
        }

        if ($GamePath) {
            $found = Get-GameVersion $GamePath
            if ($found -and $found -ne $gameVersion) { Write-Warning "This build is for R.E.P.O. $gameVersion, but you have $found. It may not work." }
        }
        else { Write-Warning 'R.E.P.O. was not found in your Steam libraries.' }

        if (Get-Process -Name REPO -ErrorAction SilentlyContinue) { throw 'R.E.P.O. is running. Close it and try again.' }

        Write-Step "Installing into $root"
        [IO.Directory]::CreateDirectory($root) | Out-Null
        foreach ($package in $packages) { Install-Package $package $temp $root $managed }

        Write-Step 'RepoXR for R.E.P.O. v0.5.4'
        foreach ($file in $files) {
            Copy-Item -LiteralPath $file.Source -Destination (Get-InstallPath $file.Name $root $managed) -Force
            # These are signatures of the original files
            $signature = (Get-InstallPath $file.Name $root $managed) + '.sig'
            if (Test-Path -LiteralPath $signature) { Remove-Item -LiteralPath $signature }
        }
        if ($managed) { Update-ModList $root }

        Write-Step 'Comparing the installed files with the published build'
        if (-not (Test-Installed $files $root $managed)) { throw 'The installed DLLs do not match the published build.' }

        Write-Host ''
        Write-Host 'Done. To play:' -ForegroundColor Green
        Write-Host '  1. Connect your headset to SteamVR and wait until it shows the controllers.'
        if ($managed) {
            Write-Host "  2. Start (or restart) your mod manager, select R.E.P.O. and the profile '$ProfileName', and press 'Start modded'."
        }
        else { Write-Host '  2. Start R.E.P.O. from Steam.' }
        Write-Host '  If the controllers do nothing, close the SteamVR dashboard (see README).'
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
