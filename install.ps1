# Installs RepoXR for R.E.P.O. v0.5.4 with everything it needs: BepInExPack, FixPluginTypesSerialization, RepoXR 1.2.3 (VR
# libraries and assets) and the DLLs of this fork. Every file is checked against a SHA-256 hash. See README.md.
#
#   .\install.ps1                          finds the game and the mod manager, asks for a folder only if it is not found
#   .\install.ps1 -Yes                     never asks
#   .\install.ps1 -Check                   only compares an installation with the published hashes
#
#   -GamePath       the folder of REPO.exe (a Steam library folder works too)
#   -ModManagerPath the data folder of r2modman or Thunderstore Mod Manager (its profiles folder or a profile works too)
#   -ProfileName    the profile to install into, created if needed
#   -Target Game    without a mod manager, straight into the game folder
param(
    [ValidateSet('Auto', 'ModManager', 'Game')][string]$Target = 'Auto',
    [string]$ProfileName,
    [Alias('ProfilesPath')][string]$ModManagerPath,
    [string]$GamePath,
    [switch]$Check,
    [switch]$Yes
)

$scriptRoot = $PSScriptRoot
if ($env:OS -ne 'Windows_NT') { throw 'This installer is for Windows.' }

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

    # What people paste: quotes, variables, spaces around it
    function Get-CleanPath([string]$Path) {
        $clean = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"', "'").Trim())
        if ($clean.Length -gt 3) { $clean = $clean.TrimEnd('\', '/') }
        $clean
    }

    # The folder of REPO.exe, from that folder, REPO.exe itself, or a Steam (library) folder
    function Resolve-Game([string]$Path) {
        $clean = Get-CleanPath $Path
        if (-not $clean) { return $null }
        if ($clean -like '*.exe') { $clean = Split-Path $clean }
        $candidates = @($clean)
        foreach ($steamapps in "$clean\steamapps", $clean, "$clean\SteamLibrary\steamapps") {
            $manifest = "$steamapps\appmanifest_3241660.acf"
            if (Test-Path -LiteralPath $manifest) {
                $match = [regex]::Match([IO.File]::ReadAllText($manifest), '"installdir"\s+"([^"]+)"')
                if ($match.Success) { $candidates += "$steamapps\common\$($match.Groups[1].Value)" }
            }
        }
        $candidates += "$clean\REPO", "$clean\common\REPO", "$clean\steamapps\common\REPO", "$clean\SteamLibrary\steamapps\common\REPO"
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath "$candidate\REPO.exe" -PathType Leaf) { return [IO.Path]::GetFullPath($candidate) }
        }
        return $null
    }

    function Find-Game {
        $roots = @()
        foreach ($key in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
            $steam = Get-ItemProperty $key -ErrorAction SilentlyContinue
            foreach ($path in $steam.SteamPath, $steam.InstallPath) { if ($path) { $roots += $path } }
        }
        foreach ($root in @($roots)) {
            $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
            if (Test-Path -LiteralPath $vdf) {
                foreach ($match in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
                    $roots += $match.Groups[1].Value.Replace('\\', '\')
                }
            }
        }
        # The usual places on every drive
        foreach ($drive in [IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }) {
            foreach ($folder in 'SteamLibrary', 'Steam', 'Games\Steam', 'Games\SteamLibrary', 'Program Files (x86)\Steam', 'Program Files\Steam') {
                $roots += Join-Path $drive.RootDirectory.FullName $folder
            }
        }
        foreach ($root in $roots) {
            $game = Resolve-Game $root
            if ($game) { return $game }
        }
        return $null
    }

    function Get-GameVersion([string]$Path) {
        $file = Join-Path $Path 'REPO_Data\sharedassets0.assets'
        if (-not (Test-Path -LiteralPath $file)) { return $null }
        $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($file))
        $match = [regex]::Match($text, 'RELEASE (v\d+(\.\d+)+)')
        if ($match.Success) { $match.Groups[1].Value }
    }

    # The folder with the R.E.P.O. profiles (and the profile, if that was given), from any folder of the mod manager
    function Resolve-ModManager([string]$Path) {
        $clean = Get-CleanPath $Path
        if (-not $clean -or -not (Test-Path -LiteralPath $clean -PathType Container)) { return $null }
        $clean = [IO.Path]::GetFullPath($clean)
        $leaf = Split-Path $clean -Leaf
        $parent = Split-Path $clean
        if ($leaf -eq 'profiles') { return @{ Profiles = $clean } }
        if ($parent -and (Split-Path $parent -Leaf) -eq 'profiles') { return @{ Profiles = $parent; Profile = $leaf } }
        foreach ($data in $clean, "$clean\DataFolder") {
            if (Test-Path -LiteralPath "$data\REPO") { return @{ Profiles = "$data\REPO\profiles" } }
        }
        if ($leaf -eq 'REPO' -and -not (Test-Path -LiteralPath "$clean\REPO.exe")) { return @{ Profiles = "$clean\profiles" } }
        # The mod manager is there, but R.E.P.O. was not selected in it yet
        if ($leaf -eq 'r2modmanPlus-local' -or $leaf -eq 'DataFolder') { return @{ Profiles = "$clean\REPO\profiles" } }
        return $null
    }

    function Find-ModManager {
        $roots = @("$env:APPDATA\r2modmanPlus-local", "$env:APPDATA\Thunderstore Mod Manager\DataFolder",
            "$env:LOCALAPPDATA\r2modmanPlus-local", "$env:USERPROFILE\r2modmanPlus-local")
        foreach ($drive in [IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }) {
            foreach ($folder in 'r2modmanPlus-local', 'Games\r2modmanPlus-local') { $roots += Join-Path $drive.RootDirectory.FullName $folder }
        }
        # Prefer one where R.E.P.O. is already set up
        foreach ($root in $roots) { if (Test-Path -LiteralPath "$root\REPO") { return $root } }
        foreach ($root in $roots) { if (Test-Path -LiteralPath $root) { return $root } }
        return $null
    }

    # Ask until the answer is usable. Enter takes the default
    function Read-Answer([string]$Question, [string]$Default, [scriptblock]$Resolve, [string]$Problem) {
        for ($attempt = 0; $attempt -lt 5; $attempt++) {
            Write-Host ''
            Write-Host $Question
            if ($Default) { Write-Host "  Press Enter for: $Default" -ForegroundColor Green }
            $answer = Read-Host '  >'
            if (-not $answer -or -not $answer.Trim()) { $answer = $Default }
            if ($answer) {
                $result = & $Resolve $answer
                if ($result) { return $result }
            }
            Write-Host "  $Problem" -ForegroundColor Yellow
        }
        throw 'No usable answer. Nothing was installed.'
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

    # The game
    $game = $null
    if ($GamePath) {
        $game = Resolve-Game $GamePath
        if (-not $game) { throw "REPO.exe was not found in '$GamePath'." }
    }
    else {
        $game = Find-Game
        if (-not $game -and -not $Yes) {
            $game = Read-Answer 'R.E.P.O. was not found. Where is it? (the folder with REPO.exe, or your Steam library folder)' '' { param($path) Resolve-Game $path } `
                'REPO.exe was not found there. In Steam: right-click R.E.P.O. > Manage > Browse local files, and copy that path.'
        }
    }

    # The mod manager
    $manager = $null
    if ($Target -ne 'Game') {
        if ($ModManagerPath) {
            $manager = Resolve-ModManager $ModManagerPath
            if (-not $manager) { throw "'$ModManagerPath' is not a folder of r2modman or Thunderstore Mod Manager." }
        }
        else {
            $found = Find-ModManager
            if ($found) { $manager = Resolve-ModManager $found }
            elseif (-not $Yes) {
                $question = 'r2modman (or Thunderstore Mod Manager) was not found. Where is its data folder?' + "`n" +
                    '  In r2modman: Settings > Browse data folder.'
                $suggestion = ''
                if ($Target -eq 'Auto') { $suggestion = 'none'; $question += ' "none" installs into the game folder instead.' }
                $answer = Read-Answer $question $suggestion {
                    param($path)
                    if ($path.Trim() -eq 'none' -and $Target -eq 'Auto') { return @{ None = $true } }
                    Resolve-ModManager $path
                } 'No mod manager was found there.'
                if (-not $answer.None) { $manager = $answer }
            }
        }
        if ($Target -eq 'ModManager' -and -not $manager) { throw 'r2modman was not found. Use -ModManagerPath.' }
    }

    # The profile
    $managed = [bool]$manager
    if ($managed) {
        $profileToUse = if ($ProfileName) { $ProfileName.Trim() } elseif ($manager.Profile) { $manager.Profile } else { 'RepoXR-v0.5.4' }
        if ($profileToUse.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $profileToUse -match '^\.*$') { throw "'$ProfileName' is not a valid profile name" }
        $root = Join-Path $manager.Profiles $profileToUse
    }
    else { $root = $game }
    if (-not $root) { throw 'R.E.P.O. was not found. Use -GamePath with the folder of REPO.exe.' }
    if ($root.Length -gt 130) { throw "The path '$root' is too long for Windows, some files would exceed 260 characters. Use a shorter folder." }

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

        if ($game) {
            $found = Get-GameVersion $game
            if ($found -and $found -ne $gameVersion) { Write-Warning "This build is for R.E.P.O. $gameVersion, but you have $found. It may not work." }
        }
        else { Write-Warning 'R.E.P.O. was not found in your Steam libraries.' }

        if (Get-Process -Name REPO -ErrorAction SilentlyContinue) { throw 'R.E.P.O. is running. Close it and try again.' }

        Write-Host "Game:          $game"
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
            Write-Host "  2. Start (or restart) your mod manager, select R.E.P.O. and the profile '$profileToUse', and press 'Start modded'."
        }
        else { Write-Host '  2. Start R.E.P.O. from Steam.' }
        Write-Host '  If the controllers do nothing, close the SteamVR dashboard (see README).'
    }
    finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
