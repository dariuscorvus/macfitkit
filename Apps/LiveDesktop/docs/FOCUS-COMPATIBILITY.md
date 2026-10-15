# Desktop-Fokus und FocusFrame — 0.3.1

Am 11. Oktober 2026 meldete der Nutzer einen FocusFrame-Rahmen beim Desktop-Klick.
Die erste LiveDesktop-Korrektur nutzt NSPanel mit `.nonactivatingPanel` bereits
beim Erzeugen; canBecomeKey/canBecomeMain bleiben false. Die dekorative Fläche
und ihr Inhalt werden nicht als Bedienungshilfen-Element angeboten.

Ein AppKit-Konstruktionstest bestätigte Nonactivation, nicht Key/Main,
Klickdurchlässigkeit, keine Verschiebbarkeit und leere AX-Kinder.
Build und installierte Ad-hoc-Signatur geprüft. Kein FocusFrame-Quellcode geändert.

Der Nutzer bestätigte anschließend: Rahmen weiterhin sichtbar. Für den Vergleich
wurde LiveDesktop vollständig beendet. Der Nutzer bestätigte den Rahmen auch
OHNE LiveDesktop. Danach wurde LiveDesktop wieder gestartet.

Damit ist das gemeldete Verhalten nicht allein von der LiveDesktop-Videofläche
verursacht. Im gelesenen FocusFrame-Code wird das AX-Fokusfenster ohne Finder-
Desktop-Ausnahme verfolgt. Der Finder stellt seinen Desktop als AX-Fläche bereit.
Die vorgeschlagene FocusFrame-Korrektur liegt in
[FocusFrame-desktop-proposal.patch](FocusFrame-desktop-proposal.patch).
Der Nutzer hat den Einbau ausdrücklich freigegeben. FocusFrame 0.7.1 wurde
im bestehenden Projekt implementiert, gebaut und im bisherigen Benutzer-
Programme-Ordner installiert. Vorherige App als lokale Sicherung aufbewahrt.

Automatisch geprüft: 32 Tests in sechs Suiten einschließlich Finder-Desktop,
normalem Finder-Fenster mit derselben Bildschirmgröße, anderen Apps und fehlenden
WindowServer-Treffern. Projektstruktur, Build, strenge Signaturprüfung und
Prozessstart erfolgreich. Der Nutzer bestätigte anschließend die sichtbare
Abnahme: freier Desktop ohne Rahmen, normale Finder-Fenster weiterhin mit Rahmen.

Die Menü- und Einstellungsoberflächen von LiveDesktop bleiben zugänglich.
Wallpaper wird weiter mit AVPlayerLayer dargestellt; keine Änderung an Videos,
System-Wallpaper, Autostart oder gespeicherter Wechsel-Auswahl.

Apple-Dokumentation: [NSPanel](https://developer.apple.com/documentation/AppKit/NSPanel).
