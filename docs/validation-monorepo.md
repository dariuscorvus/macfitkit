# Monorepo-Validierung

Stand: 15.10.2026. Ergebnisse werden je Migrationsstufe ergänzt.

## Import

- Die Remote-Main-Revisionen entsprechen den dokumentierten Quellständen.
- Beide Historien mit unsquashed Subtree-Import übernommen.
- `script/build.sh all Debug`: alle drei App-Schemes erfolgreich gebaut und Signaturen verifiziert.
- `script/build.sh all Release`: alle drei App-Schemes für das generische macOS-Ziel erfolgreich gebaut und Signaturen verifiziert.
- Keine installierte App gestartet, ersetzt oder beendet; keine Benutzerkonfiguration verändert.

## Gemeinsame Komponenten

- Lokales Package mit Core, Platform und UI; keine externen Abhängigkeiten.
- Drei Swift-Testing-Prüfungen erfolgreich: Menü-Lease/Timeout, Protokollvalidierung und stabile App-Identitäten.
- Package als Universal-Release für arm64/x86_64 gebaut.

## FocusFrame-UI

- Vollständige Effektseiten auf SwiftUI und gemeinsame Komponenten umgestellt; Rendering/AX-Fensterbeobachtung bleiben app-spezifisch.
- 34 vorhandene Core-Tests erfolgreich; Debug und Universal-Release erfolgreich gebaut.
- Gemeinsame numerische Eingabe erhält Punkt/Komma, Begrenzung und Ablehnung ungültiger Werte.
- Separater UI-Vorschaumodus nutzt eine eigene Preferences-Domain und startet keine globale Fensterbeobachtung.
- Die interaktive Screenshot-/VoiceOver-Prüfung ist derzeit durch den Computer-Use-Fehler `native pipe closed before response` blockiert (auch nach Session-Reset). Sie wird nicht als bestanden gewertet.
- Der angepasste Settings-Renderer-Harness kompiliert. Sein Lauf scheitert derzeit an der Vordergrund-/Key-Window-Voraussetzung (`Active=false, key=nil`); die nachfolgenden Live-Renderer-Prüfungen sind deshalb noch nicht als bestanden nachgewiesen.
