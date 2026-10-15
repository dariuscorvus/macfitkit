# Autostart und Wechsel — 0.3.0

Prüfstand 11. Oktober 2026, macOS 27.2, Apple Silicon.

- App mit gültiger Ad-hoc-Signatur nach `/Applications/LiveDesktop.app` installiert.
- „Beim Anmelden starten“ verwendet `SMAppService.mainApp`, kein selbst angelegtes
  LaunchAgent- oder AppleScript-Objekt. Der Schalter liest den echten Systemstatus
  beim Öffnen und beim Aktivieren der App neu.
- Aktivierung im echten Popover geprüft. macOS-Anmeldeobjektbericht bestätigt
  Bundle-ID `tech.highbyte.LiveDesktop.prototype`, URL `/Applications/LiveDesktop.app`,
  Status `enabled, allowed, notified`.
- Nicht tatsächlich abgemeldet: Die Ausführung während eines neuen Logins bleibt
  ein eigener Abnahmepunkt. Ein gewöhnlicher App-Neustart erhält die Videoauswahl.
- Drei lokale Apple-Videos markiert; „Jetzt wechseln“ wechselte von Nacht zu
  Sonnenaufgang. Während manueller Pause blieb das Video auch bei „Jetzt wechseln“
  unverändert. Der Ein-Minuten-Timer wechselte ohne manuellen Klick von
  Sonnenaufgang zu Morgen. Anschließend wurde das Intervall auf 15 Minuten gesetzt.
- Vollständiger App-Neustart bestätigt Autostart aktiv, Wechsel aktiv, 15 Minuten
  und alle drei markierten Videos. Der anschließend manuell ausgelöste Wechsel
  von Morgen zu Nacht bestätigt auch den finalen Build.
- Die Kernprüfung prüft Reihenfolge, Übergang vom letzten zum ersten Video,
  fehlende aktuelle Auswahl, doppelte Kandidaten und weniger als zwei Kandidaten.

Der Benutzer kann beide Funktionen ausschalten. Wechsel-Intervall und Liste
werden gespeichert. Der Wechsel lässt Displays ohne LiveDesktop-Video frei und
überspringt nicht mehr vorhandene Dateien. Sitzung/Schlaf, Stromspar-Pause und
thermische Pause verhindern auch einen Video-Wechsel. Timer-Toleranz: 5 Sekunden;
kein Aufholen während Schlaf verpasster Takte.

Apple-Dokumentation:
[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice),
[Freigabe erforderlich](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval).
Ein macOS-Status `requiresApproval` wird separat mit Link zu Anmeldeobjekten gezeigt,
kein lokaler Boolean als erfolgreicher Autostart ausgegeben. Fehler bleiben sichtbar.
