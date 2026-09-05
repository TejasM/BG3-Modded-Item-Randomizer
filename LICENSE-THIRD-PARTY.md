# Third-Party Notices — MIR (Modded Item Randomizer)

MIR's own code and documentation are released under the MIT License (see `LICENSE`). This file lists material that MIR depends on but does **not** own.

## BG3 Script Extender — required dependency (not included)

MIR requires the **BG3 Script Extender** by [Norbyte](https://github.com/Norbyte/bg3se) to run. The Script Extender is **not bundled** with MIR — users install it themselves. All rights remain with its author.

## Mod Configuration Menu (BG3MCM) — required dependency (not included)

MIR requires **Mod Configuration Menu** by AtilioA and contributors (NexusMods mod 9162) for every one of its settings, and disables itself when MCM is absent. MCM is **not bundled** with MIR — users install it themselves. MIR ships an MCM *blueprint* (a JSON description of its own settings, authored by MIR's author) that MCM reads; it contains no MCM code. All rights to MCM remain with its authors.

## Larian Studios — Baldur's Gate 3

MIR is an unofficial, fan-made modification for Baldur's Gate 3 and is not affiliated with or endorsed by Larian Studios. MIR ships **no Larian game files**, modified or otherwise: it contains only its own Script Extender Lua, its MCM blueprint and its mod metadata. At runtime it reads the game's item and template data through the Script Extender and adds items to containers with the engine's own inventory call; it never alters the game's data files. All rights to Baldur's Gate 3 remain with Larian Studios.

## Summary

MIR bundles no third-party binaries, tools or game files. Its two required dependencies — the Script Extender and Mod Configuration Menu — are installed separately by the user.
