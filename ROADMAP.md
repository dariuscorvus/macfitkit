# FocusFrame – nächste Entwicklungsschritte

Am 1. Oktober 2026 vom Nutzer freigegeben. Entwicklungsbasis, Darstellung und
Alltagsoptionen sind im Entwicklungsstand 0.3.0 implementiert. Praktische
Abnahmegrenzen stehen in VALIDATION.md; optionale spätere Features bleiben offen.

## Produktziel

Eine kleine native Menüleisten-App, die den Fensterfokus eindeutig sichtbar
macht und im Alltag unauffällig bleibt. Swift/AppKit, öffentliche macOS-APIs,
ereignisbasierte Aktualisierung und keine zusätzlichen Laufzeitabhängigkeiten.

## Ausgangslage

Implementiert: Bedienungshilfen-Prüfung, fokussiertes Fenster, klicktransparenter
abgerundeter Rahmen, vier Farben und vier Stärken, gespeicherte Darstellung,
AX-/Workspace-Ereignisse und Mausverfolgung bei bestätigten Titel-Ziehgesten.
Lokaler Build und acht Kernlogiktests bestehen im zuletzt dokumentierten Lauf.

Noch offen: manuelle Bestätigung der neuesten Bewegungsverfolgung, reale
Mehrschirm-/Spaces-/Vollbild-Abnahme und Verhalten bei Snap-/Resize-Gesten.
Ein erfolgreicher Build oder Prozessstart beweist keine flüssige Darstellung.

## Entwicklungsbasis

Diese Arbeiten sollen neue Features leichter überprüfbar machen:

1. **Reproduzierbare Fensterprüfung:** kleines lokales AppKit-Testfenster mit
   definierter Position/Größe und Szenarien für Fokus, Move, Resize, Minimieren
   und Schließen. Für die tatsächliche Mausverfolgung zusätzlich echte manuelle
   Ziehgesten prüfen; automatisierte Eingabe aktiviert nicht zwingend denselben Pfad.
2. **Gezielte Diagnose:** optionaler Modus mit Ereignisart, Zeitpunkt, Beginn/Ende
   der Mausverfolgung und Dauer von AX-Abfragen. Keine Inhalte, Fenstertitel oder
   dauerhaften Protokolle. Abfragezeit und sichtbarer Positionsversatz getrennt messen.
3. **Klare Zustände:** Fokuswechsel, Ziehen, Resize, Berechtigungsverlust und
   Bildschirmwechsel explizit behandeln. Unterbrochene Gesten und verspätete
   Ereignisse mit sinnvollen Regressionstests absichern.
4. **Ein lokaler Prüfaufruf:** Kernlogiktests, Build und Signaturprüfung zusammenfassen;
   echter UI-Test bleibt als solcher gekennzeichnet. Eine macOS-CI kann später
   bei vorhandenem Remote denselben reproduzierbaren Build prüfen.
5. **Nachvollziehbare Änderungen:** kleine Commits, kurze Release-Notizen,
   konkrete Abnahmekriterien pro Feature und dokumentierte Plattformgrenzen.
   Die nötigen Toolchain-Umgehungen bleiben im Build-/Testskript.

## Feature-Vorschläge

| Bereich | Feature | Nutzen / Abnahme |
| --- | --- | --- |
| Darstellung | Freie Farbe und Deckkraft | Native Farbauswahl; Ergebnis sofort sichtbar und gespeichert |
| Darstellung | Einstellbarer Eckenradius und Rahmenabstand | Runde und eckige Fenster gezielt anpassen; keine überdeckten Inhalte |
| Darstellung | Kleines Einstellungsfenster mit Vorschau | Einstellungen verständlich bearbeiten; nach Neustart identisch |
| Darstellung | Optionaler Glow | Abschaltbar; Kosten für Zeichnen und GPU prüfen |
| Alltag | Start bei Anmeldung | Über native macOS-Anmeldung, sichtbar ein-/ausschaltbar |
| Alltag | Globales Tastenkürzel | Rahmen schnell pausieren; Konflikte und Fokusverhalten prüfen |
| Alltag | App-Ausnahmen | Ausgeschlossene Apps erhalten keinen Rahmen |
| Alltag | Regeln für Vollbild | Rahmen im Vollbild nach Wunsch anzeigen oder ausblenden |
| Später | Darstellung je App / Presets | Nur bei tatsächlichem Bedarf; klare Priorität gegenüber globalen Einstellungen |

## Vorgeschlagene Etappen

- **Stabilisierung:** Bewegungsverfolgung praktisch bestätigen, Testfenster,
  Diagnose und unterbrochene Gesten absichern. Abschluss: Prüfungen reproduzierbar,
  verbleibende Probleme klar dokumentiert.
- **0.2 – Darstellung:** Einstellungsfenster, freie Farbe, Deckkraft, Radius und
  Abstand. Abschluss: Vorschau stimmt mit echtem Rahmen überein; Einstellungen
  bleiben erhalten; keine Bewegungsregression.
- **0.3 – Alltag:** Autostart, Tastenkürzel, App-Ausnahmen und Vollbildregel.
  Abschluss: Ausschalten/Ausnahmen verstecken den Rahmen sofort; Autostart und
  Tastenkürzel stehlen keinen Fokus.
- **Optional danach:** Glow, Presets und Regeln je App. Jede Erweiterung muss
  einen konkreten Alltagseinsatz rechtfertigen.

## Entscheidungsgrenzen

Ein fester Radius bleibt zunächst die verlässlich implementierbare Einstellung;
automatische exakte Erkennung aller fremden Fensterformen ist kein Versprechen.
Verteilung, Developer-ID-Signierung, Notarisierung, Installer und Updates bilden
eine eigene spätere Etappe, falls die App auch für andere gedacht ist.
Keine Veröffentlichung oder Remote-Erstellung ist Teil dieses Entwurfs.

## Umsetzungsstand

- Entwicklungsbasis: gemeinsamer Prüfaufruf, Testfenster, optionale Diagnose,
  Sichtbarkeitsregeln und Regressionstests vorhanden.
- Darstellung: native Einstellungen und gemeinsame Vorschau implementiert;
  Radius/Abstand/Deckkraft und Speicherung nach Neustart praktisch geprüft.
- Alltag: native Autostart-Registrierung, ⌃⌥F, App-Ausnahmen und Vollbildregel
  implementiert. Registrierung an/aus und Ausschlussstatus praktisch geprüft.
- Nutzer bestätigt: Ziehen deutlich besser; Vollbild in Ordnung.
- Noch manuell: reale Monitore/Spaces, tatsächlicher Login und physische Eingabe
  des globalen Tastenkürzels. Anmeldestart und Tastenkürzel wurden vom Nutzer
  noch nicht erfolgreich geprüft.
- Später: Glow, Presets, Regeln je App, Verteilung und CI bei vorhandenem Remote.
