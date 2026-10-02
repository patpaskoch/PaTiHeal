# PaTiHeal

<img src="assets/icon-128.png" width="96" alt="PaTiHeal icon">

Compact party frames for healers in World of Warcraft: Forever (Interface 16001). You click a frame, PaTiHeal casts
exactly the spell you assigned to that click — it never picks a target or a spell by itself.

> Status: in development, not yet released. Parts are tested in game (see Known limitations).

## Features
- Party frames for you and party1–4: name in class colour, health in percent, mana, offline/dead state;
  the tank gets an accent stripe
- **Heal target:** a frame for your current target directly above your own — for a friendly player or NPC that
  is alive (name, level, health, mana, your HoTs, dispellable debuffs). Same click bindings as every frame; it
  appears and disappears with your target, also in combat (WoW's secure state driver; not yet confirmed in the
  Forever client). Without a friendly target the window stays as compact as before
- Click casting for nine combinations (left, right, middle, Shift/Ctrl/Alt + left/right), each with a rank choice
- Your HoTs and shields on the frames, with charges and remaining time — Shaman: Earth Shield, Riptide;
  Priest: Renew, Power Word: Shield, Prayer of Mending. Only your own; each can be switched off;
  right of the health bar or below it
- Dispellable debuffs as small icons coloured by type (display only)
- Click dispel: put your dispel spell (e.g. Cleanse Spirit, Dispel Magic) on any click combination. Nothing is preset
- ••• menu: Settings, Lock, Collapse, Test Mode, Hide. Languages: English, Deutsch (others fall back to English)
- Works on its own; PaTiAuras is not needed. With **PaTiAlerts** installed (optional), members with a dispellable
  debuff also appear there

## PaTiSuite

This addon is part of the **PaTiSuite** — a collection of small addons for World of Warcraft: Forever.
Each one is installed on its own and works on its own; none of them is needed by another.

- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – optional control panel to show and hide the PaTi windows
- **PaTiHeal** – healing: party frames, heal target, click casting, HoTs, dispels *(this addon)*
- [PaTiAuras](https://github.com/patpaskoch/PaTiAuras) – buffs, procs, tracking, group buffs and weapon imbues
- [PaTiTank](https://github.com/patpaskoch/PaTiTank) – tank HUD and aggro monitor
- [PaTiRota](https://github.com/patpaskoch/PaTiRota) – your own skill priority with cooldowns and fixed cast buttons
- [PaTiGroup](https://github.com/patpaskoch/PaTiGroup) – party awareness: tank, healer, roles and the tank's target
- [PaTiLead](https://github.com/patpaskoch/PaTiLead) – lead the group: raid markers, ready check and pull timer
- [PaTiQuest](https://github.com/patpaskoch/PaTiQuest) – selected quest and its objectives
- [PaTiDungeon](https://github.com/patpaskoch/PaTiDungeon) – instance, group and combat status
- [PaTiSocial](https://github.com/patpaskoch/PaTiSocial) – "Party Social": quick emote and message buttons
- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – one window for open problems

### Goes well with (optional)

- [PaTiAuras](https://github.com/patpaskoch/PaTiAuras) – extra buff and aura watch next to your party frames
- [PaTiAlerts](https://github.com/patpaskoch/PaTiAlerts) – shows party members with a dispellable debuff in one central window
- [PaTiSuite](https://github.com/patpaskoch/PaTiSuite) – control panel to show and hide all PaTi windows

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

## Development

Architecture, tests and engineering rules of the suite: [PaTiAdmin](https://github.com/patpaskoch/PaTiAdmin). PaTiAdmin is not a WoW addon — players do not install it. The shared UI code (PaTiShared) is already embedded in this addon's `Shared/` folder; there is nothing extra to install.

## License
MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Patrick Koch.
