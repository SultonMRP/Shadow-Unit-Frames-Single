# Shadow Unit Frames - Single

Shadowed Unit Frames for **WotLK 3.3.5a** with a `[paragon]` tag for **SingleWoW**.

Works on **player, party, raid, target, focus, and target-of-target** when the unit is a player. Shows `0` until the server sends a number.

## Install

Download **Shadow.Unit.Frames.Single.1.1.zip** from [Releases](https://github.com/SultonMRP/Shadow-Unit-Frames-Single/releases) and extract it into `Interface\AddOns` so you have:

`Interface\AddOns\ShadowedUnitFrames\ShadowedUnitFrames.toc`  
`Interface\AddOns\ShadowedUF_Options\ShadowedUF_Options.toc`

Then `/reload`.

## Use

`/suf` → unit (player, party, raid, target, …) → **Text/Tags** → **Paragon** or **Paragon (#)**.

```
[paragon]     → 12
[()paragon]   → (12)
```

Neither tag adds a space. NPCs stay blank.

## Notes

- Based on Shadowed Unit Frames `v3.2.12-5-g3fb7edd` (`## Interface: 30300`)
- Uses SingleWoW `SWParagonOf`, not AethroParagon
- Original addon by Shadowed.
