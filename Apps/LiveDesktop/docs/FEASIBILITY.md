# Desktop-Fenster: Annahmen und Prüfstand

## API-Evidenz

- [CGWindowLevelKey](https://developer.apple.com/documentation/coregraphics/cgwindowlevelkey): öffentliche Fenster-Level.
- [desktopIconWindow](https://developer.apple.com/documentation/coregraphics/cgwindowlevelkey/desktopiconwindow): Level für Desktop-Icons.
- [NSWindow](https://developer.apple.com/documentation/appkit/nswindow): Fokus, Mausereignisse, Frame und Ordering.
- [canJoinAllSpaces](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallspaces): Fenster kann in allen Spaces erscheinen.
- [AVPlayerLooper](https://developer.apple.com/documentation/avfoundation/avplayerlooper): Queue-basierte Wiederholung.

Daraus folgt die Hypothese, dass `desktopWindow + 1` über der Wallpaper-Fläche
und unter Icons liegt. Die API-Dokumentation garantiert nicht, dass Apples
Wallpaper-Prozess und Finder stets diese Reihenfolge einhalten. `orderFrontRegardless`
ordnet nur auf dem gewählten Level; das Fenster bleibt numerisch unter normalen
Fenstern. Kein Fallback auf normale oder höhere Levels, falls die Hypothese scheitert.

## Automatische und lokale Prüfungen

Siehe `VALIDATION.md` für die tatsächlichen Ergebnisse. Technische Werte sind
keine Bestätigung für sichtbare Icons, Drag & Drop, Spaces oder Energieverbrauch.
Ein künstliches Video prüft den Player, nicht Apples Codec-/Asset-Varianten.

## Sichtbare Abnahme (noch nicht vollständig durchgeführt)

1. Normales Finder-Fenster geöffnet lassen, Video auswählen. Fenster bleibt darüber;
   Finder behält Fokus, Wallpaper nimmt keine Klicks/Tasten an.
2. Desktop-Icon auswählen, doppelklicken, verschieben, Kontextmenü und Auswahlrahmen
   prüfen. Icon bleibt sichtbar und bedienbar, Video bewegt sich dahinter.
3. „Schreibtisch zeigen“, Spaces-Wechsel, Mission Control, Stage Manager und Vollbild
   jeweils testen. Überlagerung, verschwundene Fläche oder Fenster in Übersicht melden.
4. Zweiten Bildschirm mit anderer Auflösung/Skalierung anschließen. Unterschiedliche
   Videos zuweisen, Position ändern, abziehen und wieder anschließen. Keine Restfenster.
5. Pause und Fortsetzen, Bildschirm-/Systemschlaf, Sitzungswechsel und Low Power Mode.
   Manuelle Pause darf nach System-Resume nicht aufgehoben werden.
6. Datei verschieben/löschen; ungültige MOV-Datei wählen. Fehlermeldung, kein dauerhaft
   schwarzes Fenster nach erkanntem Playerfehler; anderes Video muss auswählbar bleiben.
7. Zehn Minuten reales Apple-Video: CPU/GPU, Energie, Speicher und ruckelfreie Loops
   dokumentieren. Separat mit zwei 4K-Displays messen. Keine pauschale Energiezusage.
8. Beenden: ursprüngliches Wallpaper sofort sichtbar, keine Desktop-Fenster übrig.

Bei unzuverlässiger Reihenfolge wäre das Ergebnis „Desktop-Level-Ansatz für diese
Konfiguration ungeeignet“. Ein alternativer Ansatz braucht eigene Prüfung; die App
behauptet keine garantierte macOS-Wallpaper-API.
