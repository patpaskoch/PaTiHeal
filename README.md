# PaTiHeal

Kompakte Gruppenanzeige für manuelle Heilung. Das Addon wählt weder Ziele noch Zauber selbst:
ein Klick auf einen Gruppenbalken wirkt genau den Zauber, den du dieser Klick-Kombination zugewiesen hast.

## Funktionen
- Lebens- und Mana-Balken: Name in Klassenfarbe, Leben in Prozent, Zustände tot und offline;
  der Tank hat einen farbigen Streifen am linken Rand
- Klickzauber für neun Kombinationen: Links-, Rechts-, Mittelklick sowie Shift/Strg/Alt + Links/Rechts,
  jeweils mit Rangwahl („Höchster“ oder ein bestimmter Rang)
- Bannbare Debuffs als kleine Icons am Gruppenrahmen (nur Anzeige)
- Deine HoTs und Schilde am Gruppenrahmen, mit Aufladungen und Restzeit: Schamane Erdschild, Springflut;
  Priester Erneuerung, Machtwort: Schild, Gebet der Besserung. Nur eigene Auren; einzeln abschaltbar;
  rechts neben oder unter dem Lebensbalken
- Klick-Reinigen: Reinigungszauber (z. B. Geist reinigen, Magiebannung) lassen sich wie jeder Heilzauber auf eine
  Klick-Kombination legen. Nichts ist vorbelegt
- Läuft ohne PaTiAuras
- Menü `•••` im Fensterkopf: Einstellungen, Sperren/Entsperren, Ein-/Ausklappen, Testmodus, Ausblenden
- Einstellungsfenster mit Klickzaubern, Sprache (Automatisch, English, Deutsch, 简体中文, 繁體中文, 한국어) und Fenstersperre
- Testmodus mit Beispieldaten; Klickzauber sind dann deaktiviert

## Befehle
- `/ph settings` öffnet die Einstellungen
- `/ph show` oder `/ph hide`
- `/ph test`
- `/ph lock` oder `/ph unlock`
- `/ph spells` zeigt bekannte Heilzauber samt ID
- `/ph auras` zeigt, welche Profil-Zauber (HoTs, Schilde, Reinigen) der Client kennt
- `/ph debug` zeigt Versionen und die aktuellen Klick-Attribute

Klickzauber-Änderungen im Kampf werden nach dem Kampf übernommen. Ausblenden, Einklappen und
der Testmodus sind im Kampf gesperrt.

Gemeinsame Oberfläche: PaTiShared UI (eingebettet in `Shared/`, kein separates Addon nötig).
