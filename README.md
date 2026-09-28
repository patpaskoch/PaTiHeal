# PaTiHeal

Kompakte Gruppenanzeige für manuelle Heilung. Das Addon wählt weder Ziele noch Zauber selbst:
ein Klick auf einen Gruppenbalken wirkt genau den Zauber, den du dieser Klick-Kombination zugewiesen hast.

## Funktionen
- Lebens- und Mana-Balken mit `Name – Klasse`, Zustände tot und offline
- Klickzauber für neun Kombinationen: Links-, Rechts-, Mittelklick sowie Shift/Strg/Alt + Links/Rechts,
  jeweils mit Rangwahl („Höchster“ oder ein bestimmter Rang)
- Bannbare Debuffs als kleine Icons am Gruppenrahmen (nur Anzeige)
- Menü `•••` im Fensterkopf: Einstellungen, Sperren/Entsperren, Ein-/Ausklappen, Testmodus, Ausblenden
- Einstellungsfenster mit Klickzaubern, Sprache (Automatisch, English, Deutsch, 简体中文, 繁體中文, 한국어) und Fenstersperre
- Testmodus mit Beispieldaten; Klickzauber sind dann deaktiviert

## Befehle
- `/ph settings` öffnet die Einstellungen
- `/ph show` oder `/ph hide`
- `/ph test`
- `/ph lock` oder `/ph unlock`
- `/ph spells` zeigt bekannte Heilzauber samt ID
- `/ph debug` zeigt Versionen und die aktuellen Klick-Attribute

Klickzauber-Änderungen im Kampf werden nach dem Kampf übernommen. Ausblenden, Einklappen und
der Testmodus sind im Kampf gesperrt.

Gemeinsame Oberfläche: PaTiShared UI (eingebettet in `Shared/`, kein separates Addon nötig).
