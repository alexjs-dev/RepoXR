# RepoXR on R.E.P.O. v0.5.4: how the port works

Sources compared:

| | Version | Based on |
|---|---|---|
| [DaXcess/RepoXR](https://github.com/DaXcess/RepoXR) `main` (15b4aec) | RepoXR 1.2.3 for R.E.P.O. 0.4.4 (Unity 2022.3) | - |
| [crimecock/RepoXR](https://github.com/crimecock/RepoXR) `repo-0.5.0` | 0.5.0 (Unity 6000.3); author reports menus, levels, shop and multiplayer tested on PC | 15b4aec, 38 commits |
| [largoz/RepoXR](https://github.com/largoz/RepoXR) `repo-0.5.2` (e8bca86) | 0.5.2; patch check only, not reported as played | crimecock, 1 commit |
| Previous local port (Nov 1) | 0.5.0; compiled and passed the patch check, menus could not be used in VR | 15b4aec |

Upstream tracks 0.5.x in [issue #49](https://github.com/DaXcess/RepoXR/issues/49); its Unity 6 code is private. All of this
is GPL-3.0, so the fork's code can be reused with credit.

## General concept

RepoXR does not replace the game. It loads OpenXR next to it and patches game methods at runtime (Harmony):

1. **Start**: preload the XR libraries, load the asset bundle, start OpenXR, apply the patches.
2. **Every scene**: put head tracking on the main camera and rebuild the screen-space UI as world-space canvases.
3. **Input**: game keys (`InputKey`) are answered by VR actions; the menu pointer is a ray from the hand.
4. **Gameplay**: whatever the game aims from the camera or mouse is aimed from the hand instead.

A patch can therefore break in two ways. A changed *signature* fails loudly (it does not compile or apply). A changed
*assumption* fails silently: everything applies and nothing works. The previous port fixed the first kind only. What
makes the fork work is mostly the second kind.

## What 0.5.x changed

| Assumption RepoXR 1.2.3 made | 0.5.x | What you see |
|---|---|---|
| Skipping the menu intro is harmless | `MenuPageMain.Start` blocks interaction and raycasts until the intro has run | Pointer hits nothing |
| Hover areas are in canvas units | `UIMouseHover` multiplies by `lossyScale` (0.03 on the VR canvas) | Hover areas are specks |
| A menu is always pointed at | Gamepad support adds keyboard navigation, left only by moving the mouse | Buttons do not highlight |
| Menu pages sit at the canvas origin | They do not | Pointer and elements are offset |
| XRI's UI ray finds the UI | Reported as finding nothing on Unity 6; the scene also has a `StandaloneInputModule` | Pointer hits nothing |
| One scene at a time | Scene handoff: the next scene starts while `Reload` is still active | Lost head tracking and HUD in levels, result screen hangs |
| Menus click with the mouse button | `InputKey.UIClick` | Buttons do not click |
| Grab, rotate, climb and gun code locations | Moved to new methods | Grabbing off, guns aim from the camera |
| Key names and text tags | Renamed, tags moved to `InputGlyphs`, new vehicle keys | Missing inputs and icons |
| TextMeshPro of Unity 2022 | Unity 6 reads other fields | `?` icons, unreadable text |

Between 0.5.0 and 0.5.4 much less changed. For RepoXR: `PhysGrabber.ObjectTurning` was split up, `PostProcessing.Start`
merged into `Awake`, and `UIMouseHover` requires desktop window focus.

Not a code problem: SteamVR gives no controller input while its dashboard is open, which Steam's theater screen opens
for "flat" games. Head tracking still works then.

## Logical chunks and decisions

| # | Chunk | Main files | Decision |
|---|---|---|---|
| 1 | Signatures, renamed keys, overloads | many | Take |
| 2 | Menu pointer (the first five rows above) | `UIPatches`, `XRRayInteractorManager`, `MenuTwoOptionsPatches`, `MenuPatches` | Take, without the logging probes |
| 3 | Scene handoff | `Entrypoint`, `Actions`, `LoadingUI`, `GameHud`, `ResultScreenPatches`, `MoonUIPatches` | Take |
| 4 | Input: lookup cache, vehicle keys, tags | `InputPatches`, `VRInputSystem` | Take, without Quest bindings |
| 5 | Grab, climb, guns, whip, vehicles | `PhysGrabberPatches`, `ItemGunPatches`, `ItemMeleeWhipPatches`, `ItemVehiclePatches`, `VRCameraAim` | Take |
| 6 | Unity 6 text and icons | `GameFonts`, `Utils`, `FlatScalePatches`, `MarketingPopupPatches`, `TutorialPatches` | Take |
| 7 | Shop mirror | `MirrorPatches` | Take |
| 8 | Quest-only and extras (lamp lighting, FPS counter, flashlight shadows, post-processing switch, camera report, arm shader, head bob setting) | `Rendering/*`, `VRCameraReport`, `VRRig`, `FlashlightPatches` | Leave out |
| 9 | Unity 6 XR libraries, build from game folder, release tools | `RepoXR.csproj`, `tools` | Leave out: the bundled libraries start and deliver controllers on 0.5.4. First thing to revisit if XR itself misbehaves |
| 10 | Patch check for new game versions | `PatchCheck` | Leave out: checked offline instead |

Added on top for 0.5.4:

- Rotating objects: `ObjectTurnAccelerationGet` and `ObjectTurningInputUpdate`
- `UIMouseHover` without the desktop focus check
- `OpenXRCompatPatches` (analytics type missing in Unity 6, needed because of decision 9)
- Vehicles and pointer hovering work without desktop window focus
- Own `CosmeticPatches`/`InventoryPatches` changes kept: they no longer depend on compiler-generated names
- Catalog load that fails cleanly, Discord/YouTube buttons hidden, supported version `v0.5.4`

## Status

- Builds against the installed v0.5.4. The offline checker (every patch target, parameter and transpiler): 271 ok, 0 bad,
  9 transpilers without effect (8 replaced by `UIClick`, 1 debug text).
- The project compiles against Unity 2022 packages, so a type that changed in Unity 6 builds fine and then crashes at
  startup. That happened once (TextMeshPro's `material`), so every reference in the DLL is now also checked against the
  game's own libraries: only the optional CustomDiscoverStateLib is missing.
- **Played in VR** (SteamVR/OpenXR 2.18.4, Touch controllers): VR start, menu pointing and clicking, and loading from the
  main menu into singleplayer. Not specifically tested yet: result screen, shop, guns, whip, vehicles, mirror, VR settings
  page, multiplayer.
