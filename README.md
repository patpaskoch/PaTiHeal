# PaTiHeal

<img src="assets/icon-128.png" width="96" alt="PaTiHeal icon">

Compact party frames for healers in World of Warcraft: Forever (Interface 16001). You click a frame, PaTiHeal casts
exactly the spell you assigned to that click — it never picks a target or a spell by itself.

> Status: in development, not yet released. Parts are tested in game (see Known limitations).

## Features
- Party frames for you and party1–4: name in class colour, health in percent, mana, offline/dead state;
  the tank gets an accent stripe
- Click casting for nine combinations (left, right, middle, Shift/Ctrl/Alt + left/right), each with a rank choice
- Your HoTs and shields on the frames, with charges and remaining time — Shaman: Earth Shield, Riptide;
  Priest: Renew, Power Word: Shield, Prayer of Mending. Only your own; each can be switched off;
  right of the health bar or below it
- Dispellable debuffs as small icons coloured by type (display only)
- Click dispel: put your dispel spell (e.g. Cleanse Spirit, Dispel Magic) on any click combination. Nothing is preset
- ••• menu: Settings, Lock, Collapse, Test Mode, Hide. Languages: English, Deutsch (others fall back to English)
- Works on its own; PaTiAuras is not needed. With **PaTiAlerts** installed (optional), members with a dispellable
  debuff also appear there

## Installation
1. Download the release zip (`PaTiHeal-<version>.zip`).
2. Unpack it and copy the folder `PaTiHeal` into `World of Warcraft/<client>/Interface/AddOns/`.
3. Start WoW and enable PaTiHeal in the AddOns list.

## First steps
- `/ph settings` → Click casting: choose a spell for e.g. Left Click; "HoTs & shields" for the frame icons
- `/ph test` shows example frames (clicks do nothing in test mode)
- `/ph` shows or hides the window; drag it by its header

## Settings
`/ph settings` or ••• → Settings:
- **Click casting:** a spell and rank per click combination; dispel spells are in the same list (click dispel)
- **HoTs & shields:** each aura on/off, timers, charges, position (right of or below the health bar)
- **General:** language, scale (applied after combat if changed in combat), window lock, dispellable debuffs on/off
- *Restore Defaults* keeps your click bindings and the window position.
- **Window:** panel opacity (30–100 %)

## Commands
`/ph` or `/patiheal` — alone: show/hide · `settings` · `test` · `show` · `hide` · `lock` · `unlock` · `reset` (position) ·
`spells` (known heals with ID) · `auras` (which HoT/shield/dispel spells your client knows) · `debug` · `version`

Hide, collapse, test mode and reset are blocked in combat (WoW does not allow changing secure frames then).
Click-casting changes made in combat apply after combat.

## Known limitations
- HoT/shield and dispel spell IDs are not yet confirmed in the Forever client — `/ph auras` shows what it knows.
- Not yet tested in game: rank choice, dispel icons, HoTs & shields, click dispel.
- Party only (no raid frames).

## License
MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Patrick Koch.
