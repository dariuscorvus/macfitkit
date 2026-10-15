# Finder-Icons — Prüfung am 11. Oktober 2026

macOS 27.2, großer Bildschirm (2560 × 1080 AppKit-Punkte / 5120 × 2160 Pixel).
Lokales synthetisches H.264-Video, keine heruntergeladenen Apple-Assets.

## Bestätigte technische und funktionale Befunde

Die Fensterliste des WindowServers ist nach Front-to-back sortiert. Während
laufender Wiedergabe wurden normale Finder-Fenster vor dem Finder-Desktop und
LiveDesktop hinter dem Finder-Desktop gelistet. Die Reihenfolge ist damit
für diese Konfiguration tatsächlich beobachtet, nicht nur aus Konstanten abgeleitet.

```text
ready=true rate=1.0 loops=79 elapsed=2026-10-11 00:37:38 +0000
stack=9 owner=Finder window=21 level=-2147483603
stack=10 owner=LiveDesktop window=8085 level=-2147483622

```

Die LiveDesktop-Fensteraufnahme zeigte das bunte Video. Die Finder-Aufnahme zeigte
Icons und die Auswahlmarkierung des getesteten Ordners. Auswahl und die
Accessibility-Aktion „Öffnen“ funktionierten; das resultierende normale Finder-
Fenster wurde ausgelesen und anschließend geschlossen. Die Wiedergabe lief während
der Prüfung weiter (mehr als 50 Loops), das Fenster blieb nicht fokussierbar.

## Sichtprüfung und Grenzen der Fernsteuerung

Die Fernsteuerung nimmt App-Fenster getrennt auf; Finder-Screenshots enthalten
nur die Icon-Ebene. Ein koordinatenbasierter Rechtsklick auf den echten Desktop
scheiterte mit `noWindowsAvailable`. Elementbasierte Rechts-/Doppelklick-Aufrufe
lieferten keinen eindeutigen Nachweis. Accessibility-Öffnen ersetzt keinen echten
Doppelklick. Die macOS-Gesamtaufnahme erfasste ein anderes Vordergrundfenster und
war für diese Prüfung ungeeignet. Es gibt daher noch keinen verifizierten gemeinsamen
Screenshot von Video und Icons und keinen bestandenen echten Desktop-Maustest.
Der Nutzer bestätigte anschließend ausdrücklich: „Ja, Video sichtbar und Icons
bedienbar“. Damit ist die sichtbare Anordnung hinter den Icons sowie deren
Bedienbarkeit einschließlich des angefragten Ordner-Doppelklicks auf diesem
Display bestätigt. Ein separater Rechtsklick-/Drag-and-Drop-Test ist damit nicht
belegt; ebenso wenig andere macOS-Versionen oder Display-Konfigurationen.

## Änderungen

- Unnötiges `sharingType = .none` entfernt: die App schließt ihre Videofläche
  nicht länger absichtlich von Fensterfreigabe/Aufnahmen aus. Die konkrete
  Screen-Sharing-Kompatibilität bleibt gesondert zu prüfen.
- Eindeutiger Wallpaper-Fenstertitel, damit die Diagnose das Fenster findet.
- `--probe-seconds 1…600` und sekündliche `.progress`-Datei im Probe-Modus:
  Player-Bereitschaft, Wiedergabe, Loop-Anzahl und tatsächliche Fensterreihenfolge.
- Reproduzierbarer Build/Start über `script/build_and_run.sh`, optional mit
  Probe-Argumenten. Codex-Run-Konfiguration ergänzt. Eigenes neues Git-Repository
  ausschließlich im LiveDesktop-Projekt angelegt.

Der Desktop-Level wurde beibehalten: es gab keinen Befund, der eine Änderung
auf eine höhere Ebene rechtfertigt. Kein Fenster wird über Finder-Icons gesetzt.

## Wiederholung

Vom Projektverzeichnis aus:

```sh
./script/build_and_run.sh --probe --probe-seconds 300 --video /absolute/path/video.mp4 --report /absolute/path/probe.txt
```

`probe.txt.progress` zeigt den laufenden Test, `probe.txt` das Endergebnis.
Der Test endet automatisch und speichert keine Wallpaper-Zuordnungen.
Build und Kernprüfungen waren nach den Änderungen erfolgreich; das neue Bundle
ist weiterhin nur lokal ad-hoc signiert.
