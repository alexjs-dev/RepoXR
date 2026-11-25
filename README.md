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

## What you need

- R.E.P.O. v0.5.4 on Steam (Windows)
- A PC VR headset and [SteamVR](https://store.steampowered.com/app/250820/SteamVR/)
- [r2modman](https://thunderstore.io/c/repo/p/ebkr/r2modman/) (or another Thunderstore mod manager)
- These mods, from the mod manager:

| Mod | Version | Why |
|-----|---------|-----|
| [BepInExPack](https://thunderstore.io/c/repo/p/BepInEx/BepInExPack/) | 5.4.2305 | Loads mods |
| [FixPluginTypesSerialization](https://thunderstore.io/c/repo/p/DaXcess/FixPluginTypesSerialization/) | **1.1.3** or newer | Needed for the VR assets, 1.1.3 added this game version |
| [RepoXR](https://thunderstore.io/c/repo/p/DaXcess/RepoXR/) | 1.2.3 | VR libraries and assets, its code gets replaced by this fork |

## Install

1. In r2modman, select R.E.P.O. and create a new profile.
2. In *Online*, install **RepoXR** 1.2.3. It also installs BepInExPack and FixPluginTypesSerialization. Check the versions
   above.
3. Build this fork (see [Build from source](#build-from-source)).
4. In r2modman, open *Settings* → *Browse profile folder*, and replace these files with the ones you built:

   | Built file (`bin/Release/netstandard2.1/`) | Replaces (in the profile folder) |
   |---|---|
   | `RepoXR.dll` | `BepInEx/plugins/DaXcess-RepoXR/RepoXR/RepoXR.dll` |
   | `RepoXR.Preload.dll` | `BepInEx/patchers/DaXcess-RepoXR/RepoXR/RepoXR.Preload.dll` |

Reinstalling or updating RepoXR in the mod manager puts the original files back, so repeat step 4 afterwards.

## Start the game

1. Turn on your headset and connect it to **SteamVR**. Wait until SteamVR shows the headset and both controllers.
2. In r2modman, select the profile and press **Start modded**.
3. Put on the headset, point at the menu and press the trigger.

**The view follows your head, but the controllers do nothing:** SteamVR blocks controller input while its dashboard is
open, and can open it when a non-VR game starts. Close the dashboard with the menu button. To prevent it, open *SteamVR
Settings*, set *Advanced Settings* to *Show*, and turn off *Dashboard* → *Present Non-VR Applications on Theater Screen
Upon Launch*.

**The game does not start in VR:** make sure SteamVR is running before the game starts, then look at
`BepInEx/LogOutput.log` in the profile folder.

## Build from source

Needs the [.NET SDK 10.0](https://dotnet.microsoft.com/download/dotnet/10.0) and R.E.P.O. v0.5.4 installed.

1. Create a file named `RepoXR.csproj.user` next to `RepoXR.csproj`, with the path to your game:

   ```xml
   <Project>
       <PropertyGroup>
           <USE_TESTER>true</USE_TESTER>
           <TesterGamePath>C:\Program Files (x86)\Steam\steamapps\common\REPO</TesterGamePath>
       </PropertyGroup>
   </Project>
   ```

2. Build it:

   ```sh
   dotnet build RepoXR.csproj -c Release
   ```

The files are in `bin/Release/netstandard2.1/`.

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
