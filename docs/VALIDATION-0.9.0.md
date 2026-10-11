
## Schatten und Animationen (0.9.0)

Unter **Schatten → Farbe verwenden von** gibt es Eigene Farbe, Rahmenfarbe und
Rahmenverlauf. Verlauf übernimmt die aktuell sichtbare Oberfläche inklusive
Gold/Chrom; ohne Verlauf wird die Rahmenfarbe verwendet. Eigene Schattenfarben
bleiben gespeichert. Deckkraft, Weichheit, Ausbreitung und Versatz sind unabhängig.
Der Verlaufsschatten nutzt einen einmal pro Geometrie erzeugten weichen Alpha-Masken-
Bitmap und eine lebende Farbverlaufsebene. Rotation und Farbfluss teilen mit dem
Rahmen denselben Startzeitpunkt. Maskenauflösung ist auf einen Pixel pro Punkt
begrenzt; weiche Schatten benötigen keine Retina-Auflösung. Bei Geometrieänderung
werden die Masken neu erzeugt; breite Schatten können dadurch zusätzlichen Aufwand
beim Vergrößern verursachen. Es wird keine pauschale Verbrauchsverbesserung behauptet.

Unter **Animationen** stehen eine eigene verkleinerte Vorschau und die Presets
Dezent, Lichtläufer, Atmender Schatten und Farbfluss bereit. Presets verändern
Animationseinstellungen; Schatten-/Verlaufs-Presets aktivieren benötigte Effekte.
Die Vorschau nutzt denselben Renderer wie das Overlay. „Animation abspielen“
startet einen Fokusdurchlauf, ohne ein anderes Fenster aktivieren zu müssen.
Beim Seitenwechsel oder Schließen werden Vorschauanimationen gestoppt.

Neue Bewegungseffekte:
- Fokusimpuls: ein kurzer heller Akzent auf der Kontur, optional federnd.
- Lichtläufer: ein kurzer heller Abschnitt läuft um die Kontur.
- Rahmen zeichnen: die echte Rahmenkontur wird schrittweise sichtbar.
- Atmen: Schatten, Rahmen, Leuchten oder alles werden sanft moduliert.
  Verlaufsschatten überblenden dabei zwischen breiter und kompakter Maske;
  einfarbige Schatten verändern zusätzlich ihre Weichheit.
- Farbfluss: die Verlaufstöne gehen ineinander über, auch im Verlaufsschatten.

Dauer je Durchlauf, ein bis sechs Fokus-Durchläufe, Stärke und Bewegungsverlauf
sind einstellbar. Dauerhaft läuft bis zum Ausblenden/Pausieren. Federnd gilt für
Fokusimpuls; andere Bewegungen verwenden bei dieser Auswahl einen sanften Verlauf.
Optional übernehmen Deckkraft, Rotation und Metallreflex Dauer und Auslöser aus
der gemeinsamen Steuerung. Die bisherigen Einzelwerte bleiben gespeichert.
Die Deckkraftanimation lässt sich getrennt auf Rahmen, Leuchten, Schatten oder
alles anwenden. Stromsparmodus und „Bewegung reduzieren“ stoppen auch neue Effekte.

Bestehende Konfigurationen behalten eigene Schattenfarbe, Deckkraft auf alles
und ausgeschaltete neue Bewegungseffekte. Import/Export und Darstellungsprofile
enthalten alle neuen Optionen. Verschieben verwendet bestehende Ebenen;
Vergrößern erhält den Startzeitpunkt einer laufenden Animation.

### Validierung

34 Core-Tests einschließlich Migration, Presets, Speicherung und Stromsparmodus;
9 bestehende Renderer-Pixelprüfungen; zusätzliche Verlaufsschatten-Pixelprüfung
für räumliche Farben und transparente Mitte, native Schattenfarbe,
synchronisierte Rotation/Farbfluss, fünf Bewegungsmodi, Wiederholungen, Phasenerhalt
beim Vergrößern, getrennte Schattenanimation und Cleanup; 792 AppKit-Geometrieprüfungen.
Einstellungsfenster: sieben Bereiche, bisherige Darstellung und Live-Verfolgung,
Lichtläufer-Preset, tatsächliche Vorschauwiedergabe und Stop beim Seitenwechsel.
Prüfsystem macOS 27.2 / Apple Silicon. Intel und Mindestversion macOS 14 sind
Universal-Bauziele, aber noch nicht auf echter Hardware getestet.
