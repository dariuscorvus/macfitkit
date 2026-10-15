# 0.4.0 – 2026-10-11



Die Menüleiste enthält benannte Wechsellisten, Favoriten, Suche, eine zufällige
Reihenfolge ohne direkte Wiederholungen und die Zeit bis zum nächsten Wechsel.
Die gewählte Liste kann allen oder einzelnen Displays zugeordnet werden. Zwei
lokal verfügbare Videos sind für den automatischen Wechsel erforderlich.
Eigene Listen entstehen aus den markierten Videos über „Neue Liste / Speichern“.
Unter „Weitere Optionen“ liegen Akkupause, Stromsparpause, sanfter Übergang,
Datei-Import/-Export, Löschen der aktuellen Liste und die private Download-Seite.
Apple-Videos werden beim Übertragen über ihre Asset-ID zugeordnet. Nicht vorhandene
Videos werden gemeldet; sie werden weder heruntergeladen noch vom anderen Mac
kopiert. Eigene Dateien werden anhand ihres Dateinamens zugeordnet; gleichnamige
Dateien sollten vor dem Import eindeutig benannt werden. Autostart und konkrete
Display-IDs werden nicht zwischen Macs übernommen.

Pause, Stromsparoptionen und Listen bleiben nach Neustart erhalten. Laden,
Wiedergabe, Pause und Fehler stammen aus den tatsächlichen Player-Zuständen.
Ein Fehler bietet einen erneuten Versuch; automatische Wechsel überspringen
fehlgeschlagene Kandidaten bis zum erneuten Auswählen oder App-Neustart.
Beim Wechsel bleibt das alte Video bis zum ersten neuen Bild sichtbar. Optional
blendet das neue Bild 0,3 Sekunden ein. Maximal zwei Player pro Display sind kurz
aktiv, der alte Decoder wird anschließend freigegeben. Vorschauen werden außerhalb
der SwiftUI-Darstellung geladen und im Speicher gehalten. Dateiwächter erkennen
Änderungen in den bekannten lokalen Asset-Ordnern. Die Auswahlhöhe richtet sich
nach der verfügbaren Hauptbildschirmfläche.

Das Desktop-Fenster bleibt unter der deklarierten Icon-Ebene, nimmt keine
Mausereignisse an und kann weder Key- noch Main-Fenster werden. Das ist keine
Garantie für Finder-Reihenfolge, Spaces oder zukünftige macOS-Versionen.
Die Ebenenzuweisung erfolgt nach der NSPanel-Konfiguration, weil AppKit beim
Ändern des Floating-Verhaltens die Ebene zurücksetzt.


