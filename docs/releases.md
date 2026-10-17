# Downloadpakete erzeugen

`script/release.py` baut Apps aus einem sauberen Git-Stand und erstellt signierte, Apple-notarisierte Universal-Pakete. Benötigt werden Xcode, ein gültiges Developer-ID-Application-Zertifikat und ein zuvor eingerichtetes notarytool-Schlüsselbundprofil. Für `--publish` zusätzlich die authentifizierte GitHub CLI.

```sh
python3 script/release.py all --preview 5 --notary-profile DEIN_PROFIL
```

Optional `--publish` anhängen, um nach erfolgreicher Prüfung GitHub-Vorab-Releases anzulegen. Einzelne Apps sind ebenfalls auswählbar. Die Ausgabe liegt standardmäßig im Benutzer-Cache; `--output` wählt einen neuen, noch nicht vorhandenen Ordner. `--build-dir` und `--signing-identity` überschreiben die Build-/Signaturvorgaben.

Der Vorgang installiert keine Apps, verändert keine UserDefaults, Freigaben oder Anmeldeobjekte und schreibt keine Zugangsdaten in das Repository. Vorhandene Tags und Downloadpakete werden nicht überschrieben.

## Lizenz und Prüfung

Der vollständige MIT-Text aus der Repository-Datei `LICENSE` wird vor der Signierung unter `Contents/Resources/LICENSE` jeder App eingebettet. DMG und ZIP enthalten ihn zusätzlich als `LICENSE` neben der App. Im GitHub-Release liegt außerdem `LICENSE.txt`. Die Metadaten dokumentieren den SHA-256-Wert des Lizenztexts.

Die App wird erst nach Einbetten von Lizenz und Quellrevision signiert und bei Apple eingereicht. Nach Annahme wird ihr Ticket angeheftet. Das DMG wird separat signiert, notarisiert und mit einem Ticket versehen.

Vor einer Veröffentlichung werden die tatsächlichen DMG- und ZIP-Dateien geöffnet und kontrolliert: Lizenzbytes auf beiden Ebenen, App-Kennung, Version, Mindestversion, beide Architekturen, unveränderte Binärdatei, strikte Signaturprüfung, Notarisierungsticket und Gatekeeper. Anschließend werden Prüfsummen erzeugt und hochgeladene Assets auf Namen, Größe und vorhandene GitHub-Digests geprüft.

Eine neue Preview-Nummer erzeugt neue Tags und Dateien. Ältere Ausgaben bleiben unverändert, damit bestehende Prüfsummen und Notarisierungsnachweise nachvollziehbar bleiben. Die Preview-3-Ausgabe ergänzt gegenüber Preview 2 die MIT-Texte in den Paketen; die geplante FocusFrame-Verdeckungskorrektur ist darin noch nicht implementiert.

Preview 4 enthält die FocusFrame-Verdeckungskorrektur einschließlich Dock-Regression aus PR #9/#10 und die sichtbare Abnahme der installierten Version. Die übrigen Apps bleiben funktional unverändert und werden aus demselben Collection-Stand erneut paketiert. Die transparente Darstellung nativer Kontextmenüs ist akzeptiert; bestehende offene Plattform- und Langzeitprüfungen bleiben dokumentiert.

Preview 5 veröffentlicht MacFitKit 0.4.4 (Build 8) und UniversalPiP 0.1.2 (Build 3). Die anderen Tool-Versionen bleiben unverändert. Vor der Paketierung des Hubs werden alle vier Einzelpakete fertig signiert, notarisiert und angeheftet. Der Hub übernimmt diese geprüften Apps; seine Prüfungen aus DMG und ZIP umfassen auch die eingebetteten Tools und deren Versionen, Architekturen, Lizenztexte, Binärprüfsummen, Signaturen und Tickets. `Release-info.json` dokumentiert sie unter `bundledTools`. Gleich versionierte neue Preview-Pakete werden nicht als Update angeboten.
