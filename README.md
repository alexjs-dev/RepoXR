# RepoXR for R.E.P.O. v0.5.4 (unofficial fork)

This is an unofficial fork of [RepoXR](https://github.com/DaXcess/RepoXR), the R.E.P.O. VR mod by DaXcess. The original
RepoXR 1.2.3 supports R.E.P.O. v0.4.4; **this fork works with R.E.P.O. v0.5.4** (Unity 6).

Please report problems with this fork here, not to DaXcess. Once RepoXR officially supports your game version, use the
[original](https://thunderstore.io/c/repo/p/DaXcess/RepoXR) instead.

| This fork | R.E.P.O. | Game engine |
|-----------|----------|-------------|
| RepoXR 1.2.3 + v0.5.4 port | **v0.5.4** | Unity 6000.3.28 |

**Tested:** starting in VR through SteamVR with Touch controllers, menu pointing and clicking, and loading into
singleplayer. Other parts (shop, guns, vehicles, multiplayer...) are ported but not specifically tested yet.

## Easy install (Windows)

You need R.E.P.O. v0.5.4 on Steam, a PC VR headset with [SteamVR](https://store.steampowered.com/app/250820/SteamVR/), and
preferably [r2modman](https://thunderstore.io/c/repo/p/ebkr/r2modman/) (start it once and select R.E.P.O.). Close R.E.P.O.
and r2modman, then use **one** of these:

**Batch file**

1. Download this repository: green *Code* button → *Download ZIP*, or
   [this link](https://github.com/alexjs-dev/RepoXR/archive/refs/heads/main.zip).
2. Extract the ZIP (do not run it from inside the ZIP).
3. Double-click **`install.bat`**. If Windows warns about it, choose *More info* → *Run anyway*.

**PowerShell command**

Open PowerShell (Start menu → type `powershell`) and paste:

```powershell
irm https://raw.githubusercontent.com/alexjs-dev/RepoXR/main/install.ps1 | iex
```

Both look for the game and the mod manager in the usual places: the Steam libraries, common folders on every drive, and the
default folders of r2modman and Thunderstore Mod Manager. **Only if something is not found, they ask for it:**

- **The game folder**: the folder with `REPO.exe`, or your Steam library folder. In Steam: right-click R.E.P.O. → *Manage* →
  *Browse local files*.
- **The r2modman folder**: in r2modman, *Settings* → *Browse data folder*. Without a mod manager, type `none`: the mod then
  goes into the game folder, and you start R.E.P.O. from Steam.

The mod goes into a profile named `RepoXR-v0.5.4`, which is created if needed. Other profiles are not touched. The installer

- downloads BepInExPack, FixPluginTypesSerialization and RepoXR from Thunderstore, and checks their SHA-256 hashes;
- installs this fork's DLLs from [`dist`](dist), and compares the installed files with the published hashes.

More options (with the downloaded repository):

| Command | What it does |
|---|---|
| `install.bat -GamePath "D:\Games\REPO" -ModManagerPath "E:\r2modman"` | Uses these folders |
| `install.bat -ProfileName MyProfile` | Installs into another profile |
| `install.bat -Target Game` | Installs into the game folder |
| `install.bat -Check` | Only compares the installed DLLs with the published build |
| `install.bat -Yes` | Never asks |

`install.bat` lets PowerShell run `install.ps1` by setting `-ExecutionPolicy Bypass` for that one process. Your system setting
does not change.

## What gets installed

| Mod | Version | Why |
|-----|---------|-----|
| [BepInExPack](https://thunderstore.io/c/repo/p/BepInEx/BepInExPack/) | 5.4.2305 | Loads mods |
| [FixPluginTypesSerialization](https://thunderstore.io/c/repo/p/DaXcess/FixPluginTypesSerialization/) | 1.1.3 | Needed for the VR assets, 1.1.3 added this game version |
| [RepoXR](https://thunderstore.io/c/repo/p/DaXcess/RepoXR/) | 1.2.3 | VR libraries and assets |
| This fork (`RepoXR.dll`, `RepoXR.Preload.dll`) | v0.5.4 port | Replaces the code of RepoXR 1.2.3 |

### Install by hand

1. In r2modman, create a profile and install **RepoXR** 1.2.3 from *Online*. Check the versions above.
2. Open *Settings* → *Browse profile folder*, and replace these files with the ones from [`dist`](dist):

   | File | Replaces (in the profile folder) |
   |---|---|
   | `RepoXR.dll` | `BepInEx/plugins/DaXcess-RepoXR/RepoXR/RepoXR.dll` |
   | `RepoXR.Preload.dll` | `BepInEx/patchers/DaXcess-RepoXR/RepoXR/RepoXR.Preload.dll` |

Reinstalling or updating RepoXR in the mod manager puts the original files back. Run the installer again afterwards.

## Start the game

1. Turn on your headset and connect it to **SteamVR**. Wait until SteamVR shows the headset and both controllers.
2. In r2modman, select the profile **RepoXR-v0.5.4** and press **Start modded**.
3. Put on the headset, point at the menu and press the trigger.

**The view follows your head, but the controllers do nothing:** SteamVR blocks controller input while its dashboard is
open, and can open it when a non-VR game starts. Close the dashboard with the menu button. To prevent it, open *SteamVR
Settings*, set *Advanced Settings* to *Show*, and turn off *Dashboard* → *Present Non-VR Applications on Theater Screen
Upon Launch*.

**The game does not start in VR:** make sure SteamVR is running before the game starts, then look at
`BepInEx/LogOutput.log` in the profile folder.

## Build from source

The DLLs in [`dist`](dist) are built from this source. To build them yourself, you need the
[.NET SDK 10.0](https://dotnet.microsoft.com/download/dotnet/10.0) and R.E.P.O. v0.5.4 installed. In PowerShell, in the
downloaded repository:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

It finds the game (or use `-GamePath`), builds both DLLs into `bin/Release/netstandard2.1/`, and compares their SHA-256 hashes
with [`dist/SHA256SUMS`](dist/SHA256SUMS). Unchanged source, built with the SDK version in [`dist/BUILD.txt`](dist/BUILD.txt)
and R.E.P.O. v0.5.4, gives the same hashes. `build.ps1 -Publish` puts your own build and its hashes into `dist`, so
`install.bat` installs it.

Share only `RepoXR.dll` and `RepoXR.Preload.dll`: the build folder also contains copies of the game's own files.

## How it works

[docs/repo-0.5.4-port.md](docs/repo-0.5.4-port.md) explains the concept, what R.E.P.O. v0.5.x changed, and what this port
does about it.

Known issue: RepoXR's translated tutorial texts do not load on Unity 6. English texts are built in, other languages keep
the game's own.

## Credits and license

- [DaXcess](https://github.com/DaXcess/RepoXR): RepoXR
- [crimecock](https://github.com/crimecock/RepoXR): the port to R.E.P.O. v0.5.0, which most of this fork is based on
- [largoz](https://github.com/largoz/RepoXR): the update to v0.5.2
- [Dobutsu](https://github.com/Dobutsu/repo-quest-vr): the Quest port that parts of the v0.5.0 port come from

Licensed under the [GPL-3.0](LICENSE), like the original.
