
## Version 0.8.0

Unter Darstellung stehen „Dezent“ und „Hoher Kontrast“ sowie eigene benannte
Profile bereit. „Darstellung als Profil speichern“ speichert die aktuellen Werte;
ein vorhandener Name wird aktualisiert. Datei-Export und -Import übertragen
Darstellung, Ausnahmen, Tastenkürzel und Profile zwischen Macs. Autostart und
Bedienungshilfen-Berechtigung bleiben lokale macOS-Einstellungen.

Unter Verhalten kann das Tastenkürzel aus Buchstaben/Ziffern und Control, Option,
Command und Shift gewählt werden. Mindestens ein Modifier ist erforderlich.
Bestehende Konfigurationen behalten Control–Option–F. Konflikte bei Registrierung
werden angezeigt; macOS-/App-Kürzel können trotzdem Vorrang haben.
Eine Stromsparoption setzt Deckkraftanimation, Verlaufsrotation und bewegten
Metallreflex aus; der statische Rahmen und die gespeicherten Effekte bleiben.
Menüleiste: Version und private GitHub-Download-Seite. Beide Schwester-Apps
besitzen eigene Icons im gemeinsamen Erscheinungsbild.

Die Finder-Desktop-Klassifikation wird pro fokussiertem AX-Fenster gespeichert
und bei Fokus-/Appwechsel verworfen. AX-Messaging ist auf 50 ms pro Anfrage
begrenzt. Geometrieantworten über 150 ms oder für eine inzwischen andere
Vordergrund-App werden verworfen. Die optionale lokale Diagnose protokolliert
Abfragedauer und verworfene Antworten, ohne Titel oder Inhalte zu sammeln.
AX-Abfragen bleiben synchron; mehrere Anfragen können sich addieren. Eine
vollständige Auslagerung benötigt separate Lebenszyklus-/Fokus-Tests.

### Prüfung und Grenzen

33 Core-Tests, Einstellungsfenster mit sieben Bereichen, numerische Eingaben,
Speicherung, 9 Renderer-Pixelprüfungen und 792 reale AppKit-Geometrieprüfungen
liefen erfolgreich auf macOS 27.2 / Apple Silicon. Struktur der Xcode-Projekte
ist geprüft; mangels vollständigem Xcode erfolgte der Bau über SwiftPM.
Langsame Fremd-AX-Apps, frischer Account, Ab-/Anmelden, Intel, Mindestversion
macOS 14 und mehrere Displays benötigen weiterhin praktische Hardwaretests.
Desktop ohne Rahmen / normale Finder-Fenster mit Rahmen wurde vom Benutzer
bereits bestätigt; die Regel bleibt erhalten.
