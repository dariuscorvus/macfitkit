# DockPreview 0.2 – Implementierung und Validierung

Stand: 15. Oktober 2026.

## Implementierung

- Dock-Hit-Test über Accessibility, Beschränkung auf Anwendungs-Dock-Elemente des Dock-Prozesses. Zuordnung zur laufenden App über die App-URL.
- Fensterliste über AXWindows. Auswahl hält das ursprüngliche AX-Fensterelement; der Titel allein bestimmt nie, welches Fenster aktiviert wird.
- Fensterminiaturen über ScreenCaptureKit und SCScreenshotManager, beschränkt auf die betreffende App. Zuordnung über Fenstertitel und Geometrie; bei Mehrdeutigkeit erscheint ein Platzhalter.
- Nicht aktivierendes NSPanel mit SwiftUI-Karten; Klickannahme beim ersten Klick. Position am Dock unten, links oder rechts; Begrenzung auf den nutzbaren Bildschirm und Scrollen bei vielen Fenstern.
- 350 ms Hover-Verzögerung, 280 ms Ausblendverzögerung und schmaler Übergangsbereich zwischen Dock und Vorschau. Schnelle App-Wechsel brechen ausstehende Bildladeaufträge ab.
- Klick entminimiert das gewählte AX-Fenster, aktiviert die App und führt AXRaise nach deren Aktivierung aus. Danach werden vorderste App und fokussiertes AX-Fenster geprüft; Fehlschläge erscheinen in der Einrichtung und im lokalen Log.
- LSUIElement-Menüleistenbetrieb, Einrichtung mit getrennten Freigabeständen und Pause-Schalter. Beim Fehlen der Bildschirmaufnahme bleibt die Fensterauswahl mit Platzhaltern verfügbar.
- Keine externen Packages, keine privaten Fenster-APIs, keine Netzwerkübertragung oder Speicherung der Miniaturen. Bilder werden beim Ausblenden verworfen. Logs enthalten keine Fenstertitel oder Bildinhalte.

## Nachgewiesen

- Debug gebaut und über Launch Services gestartet, Prozess nach Start bestätigt.
- Release für das generische macOS-Ziel erfolgreich gebaut; enthält arm64 und x86_64. Beide lokalen App-Signaturen mit `codesign --verify --deep --strict` geprüft.
- Xcode meldet lediglich übersprungene App-Intents-Metadaten, da die App keine App Intents verwendet; keine Compiler- oder Linkerfehler.
- Einrichtungsfenster über Accessibility-Baum und Screenshot geprüft: beide Freigaben, Pause-Schalter und Erneut-prüfen-Knopf sichtbar.
- 16 ausführbare Regressionchecks für Geometrie und Fensterzuordnung erfolgreich (`./script/check_preview_core.sh`). Enthalten sind seitliche Docks, viele Fenster, ein links/unterhalb liegender Bildschirm, Übergangsbereich und gleichnamige/mehrdeutige Fenster.

## Lokale Signierung und Freigaben

Ein Ad-hoc-Build hat eine vom Binärinhalt abhängige Codeidentität. Während der Entwicklung wurden eingeschaltete Systemeinstellungs-Einträge beobachtet, während die laufende App mit neuer Codeidentität beide Freigaben als fehlend abfragte. Ein App-Neustart allein behob dies nicht.

Das Startskript nutzt jetzt ein bereits installiertes Apple-Development-Zertifikat, wenn vorhanden. Der lokale Debug-Build wurde damit erfolgreich signiert; die Designated Requirement bindet an Bundle-Identifier und Zertifikat und nicht mehr an einen wechselnden CDHash. Es wurde kein neues Zertifikat erstellt. Das Repository bleibt über Ad-hoc-Fallback ohne Entwicklerteam baubar. Nach dem erstmaligen Wechsel der Signatur ist eine erneute Freigabe der aktuellen App nötig.

## Laufzeittest

Ausstehend: tatsächlicher Dock-Hover, gerenderte Miniaturen und Auswahl zwischen zwei Fenstern. Derzeit ist die Freigabe für die neue stabile Codeidentität noch zu bestätigen. Diese Punkte sind durch erfolgreiche Builds oder Core-Checks nicht nachgewiesen.

## Einschränkungen

- Momentaufnahmen beim Öffnen; kein kontinuierliches Live-Video.
- Minimierte oder nicht erfassbare Fenster zeigen einen Platzhalter; Entminimieren ist implementiert, aber noch nicht im vollständigen Ablauf bestätigt.
- Fenster auf anderen Spaces, Vollbild-Apps, mehrere Displays, ein automatisch verstecktes Dock und Apps mit unvollständigem Accessibility-Baum benötigen eigene Laufzeittests.
- Kein Intel-Hardware- oder macOS-14-Lauf und keine Notarisierung geprüft.

## Apple-Referenzen

- [AXUIElementCopyElementAtPosition](https://developer.apple.com/documentation/applicationservices/1462077-axuielementcopyelementatposition): Hit-Test in Bildschirmkoordinaten mit Ursprung oben links.
- [SCContentFilter für ein einzelnes Fenster](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init(desktopindependentwindow:))
- [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager)
