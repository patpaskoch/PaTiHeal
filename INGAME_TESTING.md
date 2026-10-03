# Ingame Testing – PaTiHeal

World of Warcraft: Forever
Interface: 16001

Diese Datei dokumentiert ausschließlich Tests im echten WoW-Client.

Automatisierte Tests, CI und Code Review zählen NICHT als Ingame-Verifikation.
Regeln und Eintragen von Ergebnissen: [PaTiAdmin/docs/TESTING.md](https://github.com/patpaskoch/PaTiAdmin/blob/main/docs/TESTING.md#in-game-test-files).

Die Bestätigungen vom 2026-09-28 stammen aus einem Build vor HoTs/Schilden, Dispels und Größe; beim nächsten
Fresh-Install-Test (PT-HEAL-001) werden sie ohnehin mitgeprüft.

## Legende

- [ ] offen / noch nicht bestätigt
- [x] vom Owner im echten Client bestätigt
- ❌ FAIL = im echten Client fehlgeschlagen
- 🔧 FIX IMPLEMENTED = Codefix vorhanden, Retest noch offen
- ✅ VERIFIED = erfolgreich im echten Client bestätigt
- MANUAL RETEST REQUIRED = erneuter Test notwendig

## Installation / Laden

- [ ] PT-HEAL-001 Fresh Install aus dem Release-ZIP: genau ein Ordner `PaTiHeal/`, Addon lädt allein
- [ ] PT-HEAL-002 PaTiHeal erscheint in der AddOn-Liste mit Beschreibung
- [x] PT-HEAL-003 Icon in der AddOn-Liste korrekt, keine weiße oder fehlende Textur
  - ✅ VERIFIED 2026-10-02
  - Owner: die Icons erscheinen im Spiel in der AddOn-Liste korrekt.
- [x] PT-HEAL-004 Login ohne Lua-Fehler
  - ✅ VERIFIED 2026-09-28
- [ ] PT-HEAL-005 `/reload` ohne Lua-Fehler

## Fenster

- [ ] PT-HEAL-010 `/ph` bzw. `/patiheal` blendet das Fenster ein und aus; `/ph show`, `/ph hide`
- [ ] PT-HEAL-011 Fenster am Header verschieben (entsperrt)
- [ ] PT-HEAL-012 Position bleibt nach `/reload`
- [ ] PT-HEAL-013 Lock/Unlock (••• und `/ph lock` / `unlock`): gesperrt nicht verschiebbar
- [ ] PT-HEAL-014 Größe (Scale) wirkt; im Kampf geändert → erst nach dem Kampf angewendet
- [x] PT-HEAL-015 Einstellungen öffnen (`/ph settings` und •••) und speichern
  - ✅ VERIFIED 2026-09-28
- [ ] PT-HEAL-016 Collapse/Expand über •••, Zustand bleibt nach `/reload`
- [ ] PT-HEAL-017 Test Mode `/ph test` zeigt Beispielrahmen; Klicks im Test Mode zaubern nichts
- [ ] PT-HEAL-018 Panel-Deckkraft 30–100 %: nur der Hintergrund ändert sich, Balken und Texte bleiben
- [ ] PT-HEAL-019 Keine Einrast-Einstellung mehr, Fenster frei verschiebbar
- [ ] PT-HEAL-020 `/ph reset` setzt die Position zurück
- [ ] PT-HEAL-021 `/ph spells` listet bekannte Heilzauber mit ID; `/ph auras` listet HoT-, Schild- und Dispel-Zauber

## SavedVariables

- [ ] PT-HEAL-030 Einstellungen (Klickbelegung, HoTs, Größe, Sprache) bleiben nach `/reload`
- [ ] PT-HEAL-031 Einstellungen bleiben nach Relog
- [x] PT-HEAL-032 Update mit alten Einstellungen: bisherige Klickbelegung wird übernommen
  - ✅ VERIFIED 2026-09-28
- [ ] PT-HEAL-033 „Standard wiederherstellen“ behält Klickbelegung und Position

## Sprachen

- [ ] PT-HEAL-040 deDE: alle Texte deutsch
- [x] PT-HEAL-041 Sprachwahl in den Einstellungen gilt nach `/reload`
  - ✅ VERIFIED 2026-09-28
- [ ] PT-HEAL-042 zhCN/zhTW/koKR: Englisch als Rückfall, keine Schlüsselnamen oder Kästchen
- [ ] PT-HEAL-043 Keine abgeschnittenen wichtigen Texte (deDE), auch in der Klickbelegung

## Party Frames

- [ ] PT-HEAL-050 Spieler und party1–4 sichtbar, Name in Klassenfarbe
- [ ] PT-HEAL-051 Leben in Prozent aktualisiert sich
- [ ] PT-HEAL-052 Mana aktualisiert sich
- [ ] PT-HEAL-053 Tank hat den Akzentstreifen
- [ ] PT-HEAL-054 Mitglied tritt bei / verlässt die Gruppe (auch im Kampf: Rahmen stimmen spätestens nach dem Kampf)
- [ ] PT-HEAL-055 Offline-Mitglied wird als offline angezeigt
- [ ] PT-HEAL-056 Totes Mitglied wird als tot angezeigt
- [ ] PT-HEAL-057 Solo: Fenster nur so hoch wie der eigene Rahmen, kein Leerraum darunter
  - ❌ FAIL 2026-10-02
  - Solo nur der eigene Balken, das Fenster blieb aber so hoch wie für fünf Rahmen.
  - 🔧 FIX IMPLEMENTED 2026-10-02
  - Höhe folgt den vorhandenen Gruppenmitgliedern (`Logic.RowCount`), außerhalb des Kampfes.
  - MANUAL RETEST REQUIRED
- [ ] PT-HEAL-058 Gruppe mit 2, 3 und 5: Fenster wächst und schrumpft mit, kein Rahmen abgeschnitten
- [ ] PT-HEAL-059 Beitritt/Verlassen im Kampf: Rahmen erscheint/verschwindet, die Höhe passt sich nach dem Kampf
  an; kein Lua-Fehler, kein ADDON_ACTION_BLOCKED
- [ ] PT-HEAL-079 Test Mode zeigt weiterhin alle fünf Beispielrahmen in voller Höhe; Einklappen = nur Header

## Click Healing

Jeweils: Zauber landet auf der angeklickten Einheit, das eigene Ziel ändert sich nicht unerwartet, gewählter Rang.

- [x] PT-HEAL-060 Linksklick zaubert den gewählten Zauber
  - ✅ VERIFIED 2026-09-28
- [ ] PT-HEAL-061 Rechtsklick
- [ ] PT-HEAL-062 Mittelklick
- [ ] PT-HEAL-063 Shift + Linksklick
- [x] PT-HEAL-064 Shift + Rechtsklick
  - ✅ VERIFIED 2026-09-28
- [ ] PT-HEAL-065 Strg + Linksklick
- [ ] PT-HEAL-066 Strg + Rechtsklick
- [ ] PT-HEAL-067 Alt + Linksklick
- [ ] PT-HEAL-068 Alt + Rechtsklick
- [ ] PT-HEAL-069 Rangwahl: gewählter Rang wird gezaubert (nicht immer der höchste)
- [ ] PT-HEAL-070 Belegung umstellen (z. B. Strg+Links → Shift+Links): alte Kombination zaubert nichts mehr
- [ ] PT-HEAL-071 Belegung im Kampf geändert → gilt nach dem Kampf
- [x] PT-HEAL-072 Linksklick auf den eigenen Spielerframe führt den konfigurierten Heal aus
  - ✅ VERIFIED 2026-09-30
  - Nur Linksklick auf den eigenen Frame bestätigt (nicht party1–4, keine anderen Kombinationen).

## HoTs / Shields

Jeweils: erscheint nur bei eigenem Cast, Timer, Aufladungen (falls vorhanden), verschwindet, Position rechts/unten.

- [ ] PT-HEAL-080 Schamane: Erdschild mit Aufladungen
- [ ] PT-HEAL-081 Schamane: Springflut (Riptide) mit Timer
- [ ] PT-HEAL-082 Priester: Erneuerung (Renew) mit Timer
- [ ] PT-HEAL-083 Priester: Machtwort: Schild mit Timer
- [ ] PT-HEAL-084 Priester: Gebet der Besserung mit Aufladungen
- [ ] PT-HEAL-085 HoT/Schild eines anderen Heilers erscheint nicht
- [ ] PT-HEAL-086 Einstellung „rechts vom Lebensbalken“ / „unter dem Lebensbalken“ wirkt
- [ ] PT-HEAL-087 Einzelne Auren abschaltbar; Timer- und Aufladungs-Schalter wirken

## Dispels

- [ ] PT-HEAL-090 Bannbarer Debuff erscheint als kleines Icon am Mitglied
- [ ] PT-HEAL-091 Icon-Farbe entspricht dem Typ (Magie, Krankheit, Gift, Fluch)
- [ ] PT-HEAL-092 Schalter „bannbare Debuffs“ aus → keine Icons
- [ ] PT-HEAL-093 Klick-Reinigen: Dispel-Zauber auf einer Kombination entfernt den Debuff am angeklickten Mitglied
- [ ] PT-HEAL-094 Mit PaTiAlerts: Mitglied mit bannbarem Debuff erscheint dort (Hinweis), nach dem Bannen weg

## Heal-Ziel (Target-Balken)

Neu 2026-10-02: ein fester Secure-Balken für dein aktuelles Ziel direkt über deinem eigenen Balken. Sichtbarkeit im Kampf
über WoWs Secure State Driver (noch nicht im Forever-Client bestätigt, `/ph debug` zeigt „driver yes/no“).

- [ ] PT-HEAL-130 `/ph debug`: Zeile „heal target: RegisterStateDriver … driver …“ (Ausgabe melden)
- [ ] PT-HEAL-131 Freundlicher NPC als Ziel: Ziel-Balken erscheint über deinem Balken mit „Ziel“, Name, St. (Level),
  Leben in %; Fenster genau eine Zeile höher, nichts abgeschnitten
  - ❌ FAIL 2026-10-03
  - Owner: Lua-Fehler „RestrictedFrames.lua:478: Invalid relative frame handle“ beim Registrieren des Treibers und
    beim Anvisieren eines freundlichen Ziels (state-healtarget = show).
  - 🔧 FIX IMPLEMENTED 2026-10-03
  - Der Secure-Snippet verankert die Spielerzeile jetzt am Ziel-Balken statt am (ungeschützten) Fenster und ändert
    die Fensterhöhe nicht mehr; die Höhe folgt außerhalb des Kampfes.
  - MANUAL RETEST REQUIRED
- [ ] PT-HEAL-132 Fremder freundlicher Spieler als Ziel: Balken erscheint, Name in Klassenfarbe, Mana falls vorhanden
- [ ] PT-HEAL-133 Gruppenmitglied (oder du selbst) als Ziel: Balken erscheint zusätzlich, beide Balken zeigen dasselbe
- [ ] PT-HEAL-134 Gegner als Ziel: kein Ziel-Balken; kein Ziel: kein Ziel-Balken, Fenster so kompakt wie vorher
- [ ] PT-HEAL-135 Totes freundliches Ziel: kein Ziel-Balken
- [ ] PT-HEAL-136 Ziel wechseln (freundlich → Gegner → freundlich) außerhalb des Kampfes: Balken und Höhe folgen sofort
- [ ] PT-HEAL-137 Ziel wechseln im Kampf: Balken erscheint/verschwindet, dein Balken und die Gruppe rücken mit (die
  Fensterhöhe folgt erst nach dem Kampf — bis dahin darf die unterste Zeile überstehen bzw. Leerraum bleiben); kein
  Lua-Fehler, kein `ADDON_ACTION_BLOCKED`
- [ ] PT-HEAL-138 Linksklick auf den Ziel-Balken wirkt genau den Zauber der Linksklick-Belegung auf das Ziel
- [ ] PT-HEAL-139 Shift-/Strg-/Alt-Klicks auf dem Ziel-Balken: jeweils genau der belegte Zauber
- [ ] PT-HEAL-140 Eigener HoT/Schild auf dem Ziel (z. B. Springflut / Erneuerung) erscheint mit Restzeit
- [ ] PT-HEAL-141 Bannbarer Debuff auf dem Ziel erscheint als Icon (falls testbar)
- [ ] PT-HEAL-142 Level: normale Zahl; Boss/unbekannt „??“
- [ ] PT-HEAL-143 `/reload` mit freundlichem Ziel: Balken sofort richtig; Test Mode zeigt „Verwundeter Soldat · St. 42“
- [ ] PT-HEAL-144 Gruppengröße 1 / 3 / 5 jeweils mit und ohne Ziel: Höhe stimmt, kein Rahmen abgeschnitten
- [ ] PT-HEAL-145 Einklappen: nur Header, auch mit Ziel; Ausklappen: alles wieder da
- [ ] PT-HEAL-146 `taint.log` ohne PaTiHeal-Eintrag nach Zielwechseln im Kampf
- [ ] PT-HEAL-147 Ziel-Balken erzeugt keine PaTiAlerts-Meldung (bannbarer Debuff am NPC-Ziel)
- [ ] PT-HEAL-148 Ziel-Balken wirkt als eigener Bereich: eigene Fläche mit Rahmen und Akzentstreifen links, „ZIEL“ in
  Akzentfarbe, sichtbar größerer Abstand (12 px) zu deinem Balken; Name, Stufe, Leben, Mana, HoTs, Debuffs unverändert
- [ ] PT-HEAL-149 Kein freundliches Ziel: keine Fläche, kein „ZIEL“, kein Leerraum über deinem Balken (solo und in der
  Gruppe, auch nach `/reload`)
- [ ] PT-HEAL-150 Test Mode: „Verwundeter Soldat · St. 42“ steht im abgesetzten Ziel-Bereich; Fenster nicht abgeschnitten
- [ ] PT-HEAL-151 Zielwechsel außerhalb und im Kampf mit der neuen Darstellung: Fläche kommt und geht mit dem Balken, kein
  Lua-Fehler, kein `ADDON_ACTION_BLOCKED`, Klickheilen auf das Ziel unverändert
- [ ] PT-HEAL-152 Ziel-Bereich in allen drei Themes: Default subtil, WoForever warm mit Bronze-/Goldrahmen, Dracula dunkel
  mit Lila-Akzent; Abstand und Größe in allen Themes gleich

## Unabhängigkeit

- [ ] PT-HEAL-100 Ohne PaTiAlerts und ohne PaTiAuras: unverändert, kein Lua-Fehler

## Combat / Sicherheit

- [ ] PT-HEAL-110 Kein Lua-Fehler im Kampf
- [ ] PT-HEAL-111 Keine `ADDON_ACTION_BLOCKED` / `ADDON_ACTION_FORBIDDEN`
- [ ] PT-HEAL-112 `taint.log` (`/console taintLog 1`) ohne PaTiHeal-Eintrag
- [ ] PT-HEAL-113 Im Kampf gesperrt mit Hinweis: Ausblenden, Collapse, Test Mode, Position zurücksetzen
  (Menüeinträge ausgegraut)

## Combined

- [ ] PT-HEAL-120 Zusammen mit allen PaTi-Addons geladen: kein Lua-Fehler
- [ ] PT-HEAL-121 Keine Slash-Command-Kollision: `/ph` und `/patiheal` antworten nur PaTiHeal
- [ ] PT-HEAL-122 Eigene Einstellungen speichern nur PaTiHeal-Werte; Fenster erscheint in PaTiSuite
