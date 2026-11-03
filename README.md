# Shadow Unit Frames - Single

Shadowed Unit Frames for **WotLK 3.3.5a** with a `[paragon]` tag for **SingleWoW**.

Uses the server `SWParagonOf` stream (same as SingleWoWParagon). Players only. Your own frame shows `0` until the server sends a number.

## Install

Download **Shadow.Unit.Frames.Single.1.0.zip** from [Releases](https://github.com/SultonMRP/Shadow-Unit-Frames-Single/releases) and extract it into `Interface\AddOns` so you have:

`Interface\AddOns\ShadowedUnitFrames\ShadowedUnitFrames.toc`  
`Interface\AddOns\ShadowedUF_Options\ShadowedUF_Options.toc`

Then `/reload`.

## Use

`/suf` → unit (player, target, …) → **Text/Tags** → enable **Paragon**, or type the tag.

```
[paragon]                  → 0
[( )paragon]               →  0
[level][( )paragon]        → 80 0
```

`[( )paragon]` is SUF’s “space then number” syntax.

## Notes

- Based on Shadowed Unit Frames `v3.2.12-5-g3fb7edd` (`## Interface: 30300`)
- Do not use the Aethro `[paragon()]` checkbox. That tag is the same as `[paragon]` in SUF.
- Other players stay blank until the server has sent their name.
- Original addon by Shadowed.
