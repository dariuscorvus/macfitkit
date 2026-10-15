# Monorepo-Validierung

Stand: 15.10.2026. Ergebnisse werden je Migrationsstufe ergänzt.

## Import

- Die Remote-Main-Revisionen entsprechen den dokumentierten Quellständen.
- Beide Historien mit unsquashed Subtree-Import übernommen.
- `script/build.sh all Debug`: alle drei App-Schemes erfolgreich gebaut und Signaturen verifiziert.
- `script/build.sh all Release`: alle drei App-Schemes für das generische macOS-Ziel erfolgreich gebaut und Signaturen verifiziert.
- Keine installierte App gestartet, ersetzt oder beendet; keine Benutzerkonfiguration verändert.
