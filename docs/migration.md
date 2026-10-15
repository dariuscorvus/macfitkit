# Migration nach MacFitKit

Entwicklungsbasis ist `dariuscorvus/macfitkit`. Die bisherigen Repositories bleiben unverändert erhalten.

| Tool | Quelle | Importierter Main-Commit | Version | Bundle-ID |
|---|---|---|---|---|
| FocusFrame | https://github.com/dariuscorvus/FocusFrame | 15e3b58e548fad876c34a4ec5d7503691b13479a | 0.9.0 / 9 | de.highbytetech.FocusFrame |
| LiveDesktop | https://github.com/dariuscorvus/LiveDesktop | 21e90a2769f906c03b15e916b6e55e5adf753e03 | 0.4.0 / 5 | tech.highbyte.LiveDesktop.prototype |
| DockPreview | bereits MacFitKit | 6827ab0d1a26d147a333b5e3b0b6aee29ab769cb | 0.2.0 / 2 | tech.highbyte.macfitkit.DockPreview |

Am 15.10.2026 vor dem Import gegen die GitHub-Main-Refs geprüft. FocusFrame und LiveDesktop wurden mit `git subtree add` ohne Squash übernommen: die originalen Commits sind weiterhin Vorfahren der Import-Commits. Keine verschachtelten .git-Verzeichnisse oder Build-Artefakte importiert.

Alle drei Apps sind eigenständige Workspace-Schemes. LiveDesktop behält macOS 26 als Mindestversion, die beiden anderen macOS 14. Konfigurationen, UserDefaults-Schlüssel und App-Identitäten bleiben erhalten. Die Quellmigration installiert oder startet keine App und setzt keine Datenschutzfreigaben zurück.

Builds und Prüfergebnisse werden in `validation-monorepo.md` fortgeschrieben. Historische Readmes/Release-Skripte in den importierten App-Verzeichnissen sind als Herkunft erhalten; der Workspace und die Root-Skripte sind die gemeinsame Build-Basis.
