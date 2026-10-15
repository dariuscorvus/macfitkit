# Lokaler Prüfstand — 11. Oktober 2026

Dieser Bericht beschreibt den ersten Machbarkeitstest (0.1.0).
Die nachfolgend noch offenen Menüinteraktionen und Apple-Videos wurden in 0.2.0
geprüft: [aktueller Apple-Auswahl-Test](APPLE-LIBRARY.md).

Umgebung: macOS 27.2 (26B5091g), Apple Silicon, Swift 6.4 / Swift-6-Sprachmodus,
Command Line Tools, kein vollständiges Xcode. Mindestziel macOS 26.0.
Die tatsächliche Ausführung auf macOS 26 ist noch nicht geprüft.

## Bestätigt

- App-Build erfolgreich, native SwiftPM-Route mit Cache außerhalb von Documents.
- `scripts/check-core.sh` erfolgreich: reguläre lokale Videodateien, verschachtelte
  Ordner, Duplikate, Symlink-Ausschluss, fehlender Ordner sowie alle 16 Kombinationen
  manueller Pause, Schlaf, Low Power Mode und thermischer Blockierung.
- App-Bundle ad-hoc signiert; `codesign --verify --strict` erfolgreich sowohl am
  Cache-Bundle als auch nach Entpacken der ausgelieferten ZIP-Datei.
- AVPlayerLayer / AVPlayerLooper über acht Sekunden mit lokal erzeugtem 2-Sekunden-
  H.264-Testvideo geprüft. Drei Loops gemeldet, erster Frame bereit, Rate 1.0.
  Fenster sichtbar laut AppKit, klickdurchlässig, nicht Key-Window. Die Vordergrund-
  App blieb Codex; der Test hat keinen Fokus übernommen.
- Ein vorangegangener 30-Sekunden-Player-Test blieb am Ende bereit und aktiv.
- Der gewöhnliche Apple-Asset-Ordner existiert auf diesem Mac nicht.

Messwert des finalen Builds:

```text
PROBE level=-2147483622 desktop=-2147483623 icons=-2147483603 ignoresMouse=true key=false canKey=false frame=(0.0, 0.0, 2560.0, 1080.0) visible=true ready=true rate=1.0 time=2.001687167 items=3 loops=3 frontmostBefore=com.openai.codex frontmostAfter=com.openai.codex
```

## Offen / konkrete Grenzen

- `swift test` konnte nicht abgeschlossen werden: Standard-Buildweg zunächst
  Signierungsfehler durch Dateimetadaten, anschließend fehlendes Testing-Macro-
  Plugin; native Route ohne nutzbares Testing/XCTest-Modul in diesen CLT.
  Die separaten Kernprüfungen verwenden dieselben XCTest-Testmethoden mit einer
  einfachen Assertion-Hülle. Sie ersetzen keine UI- oder Systemintegrationstests.
- Numerisch: Wallpaper-Level -2147483623, App -2147483622, Icons -2147483603.
  Dies belegt die eingestellten Levels, nicht die sichtbare Finder-Reihenfolge.
- Die Finder-Fensteraufnahme zeigte Icons, war aber keine geeignete Gesamtaufnahme
  des Compositors. Sie bestätigt keinen animierten Hintergrund hinter den Icons.
- Die Menüleisten-App wurde gestartet; die native UI-Automation zum Auslesen der
  Menüleiste endete mit `timeoutReached`. Sichtbare Menüinteraktionen bleiben offen.
- macOS 26, echte Apple-Videos, Multi-Display-Hotplug, Spaces, Mission Control,
  Stage Manager, Desktop-Gesten und Energieprofil bleiben sichtbar zu prüfen.
- Die Signatur ist kein Notarisierungs- oder Gatekeeper-Akzeptanznachweis.

Abnahmeschritte: [FEASIBILITY.md](FEASIBILITY.md).

## Finder-Icon-Folgeprüfung

Aktuelle Befunde einschließlich bestätigter Sicht- und Bedienprüfung durch den Nutzer: [ICON-TEST.md](ICON-TEST.md).
