# Grafana-Runtime-Schlüssel: SEC-02

Vorbereiteter Stand vom 03.10.2026. `hosts/prod/grafana-runtime-key.nix` ist **unimportiert**.
Ein normaler Deploy schaltet die Migration nicht ein. Produktion wird erst nach eigenem
Inhaber-Go für diesen Release aktiviert. `hosts/prod/grafana.nix` behält bis dahin den
bisherigen Wert. Die Produktionsdatenbank wurde für diese Vorbereitung nicht gelesen.

## Vertrag und Grenzen

Geprüft ist Grafana **13.0.7 OSS**, SQLite, Provider `secretKey.v1` und der bekannte
öffentliche Altdefault. Der neue Schlüssel besteht aus 32 zufälligen Bytes als 64
Hexzeichen. Er liegt ausschließlich SOPS-verschlüsselt in
`hosts/prod/grafana-runtime-key.yml`, mit derselben Age-/PGP-Empfängergruppe wie die
bisherige Prod-Secretdatei. Die eigene Datei verändert die bisherige SOPS-Hostdatei nicht.
Bei Aktivierung installiert SOPS ihn als `grafana/secret_key`, Eigentümer `grafana`,
Modus `0400`. Grafanas File-Provider liest ihn zur Laufzeit; Klartext gehört weder
in Git/Nix-Store noch in Argumente, Logs oder Belege. Schlüssel bei Deploy/Neustart
weiterverwenden und gemeinsam mit der Datenbank privat sichern.

`grafana-key-migration` öffnet die Quelle nur lesend, erzeugt eine neue private SQLite-Kopie
und ändert diese in einer Transaktion. Alle DEKs werden mit dem alten Schlüssel entschlüsselt,
mit dem neuen umhüllt und vollständig rückgeprüft; IDs/Provider/Labels bleiben erhalten.
Envelope-Payloads bleiben bytegleich. Direkte alte Payloads werden mit dem neuen Schlüssel
verschlüsselt. Unterstützt: Datasource-/Plugin-JSON, Secret-KV, Kontaktpunkte in
`alert_configuration`, Snapshot-, OAuth-, Signing-Key- und externe Sitzungsspalten.
Gezählt und geprüft werden alle vorhandenen unterstützten Payloads einschließlich inaktiver
DEKs. Unbekannte Provider, kaputte Payloads, unerwartete Schemata, belegte SSO-Einstellungen
Provisioning-Repositories oder belegte Unified-Secretstores (`secret_data_key`/`secret_encrypted_value`) stoppen die Migration und verwerfen die neue Kopie.
Solche Fälle brauchen eine Erweiterung samt erneutem VM-Test. Zusätzliche Enterprise-
oder separat konfigurierte Secret-Datenbanken sind außerhalb dieses Vertrags.

CFB besitzt keine Authentifizierung. Darum akzeptiert das Werkzeug als alten Schlüssel nur
den Fingerprint des hier geprüften Defaults, prüft unterstützte Secrettexte als UTF-8 und
validiert jede neue DEK-Hülle gegen ihre alten Bytes. Das ersetzt die reale Abnahme der
Verbraucher vor der Aktivierung nicht. Es gibt keinen einfachen Schlüsseltausch mit
anschließendem `re-encrypt-data-keys`: Der OSS-Provider stellt keinen zweiten Altkey bereit.

## Vorab bauen und prüfen

Auf der vorgesehenen Mainbasis den vorhandenen normalen System-/Recoverystand festhalten.
Den Kandidaten in einem eigenen Release-Worktree bauen, ausschließlich den Import
`./grafana-runtime-key.nix` in `hosts/prod/default.nix` ergänzen. Alarmierung ist eine eigene
Freischaltung: `./alerting.nix` nur übernehmen, wenn Root sie für diesen Release vorsieht.
Die Grafana-Provisionierung daraus fügt `academy-prometheus` ohne Passwort hinzu;
bestehende Datasources/Kontaktpunkte werden davon nicht ersetzt. Beide Imports zusammen
wurden für diese Vorbereitung ausgewertet und gebaut.

```bash
set -euo pipefail
nix build --no-link -L .#grafana-key-migration-tests
nix build --no-link -L .#grafana-key-migration
nix build --no-link -L .#grafana-key-activation # vorbereitet, mit beiden unimportierten Modulen
nix build --no-link -L .#nixosConfigurations.prod.config.system.build.toplevel
```

Der VM-Test erzeugt die Secrets mit echten Grafana-APIs. Ein lokaler HTTP-Dienst akzeptiert
die Datasource-Anfrage und den Kontaktpunkt-Test ausschließlich mit dem gespeicherten
jeweiligen Passwort. Das wird auf Altstand, migriertem Stand, nach Neustart und nach
Restore geprüft. Außerdem: alter Direktpayload, unbekannter Provider, falscher Altkey,
unveränderte Quelle, verweigertes Überschreiben, Startguard, Dateirechte und dieselbe
Prometheus-Provisionierung wie bei der vorbereiteten Prod-Alarmierung. Kein Anbieterschlüssel
und kein echter externer Kontaktpunkt werden gebraucht.

## Aktivierung durch Root nach Prod-Go

Die folgende Reihenfolge ist ein Wartungsfenster für Grafana. Root verwendet die bestehenden
SSH-/SOPS- und Standard-Deploywerkzeuge, kopiert Derivationsclosure und Outputs und bindet die
Abnahme an den tatsächlichen Kandidaten. Keine neue Releaseautomatik einrichten.

1. Laufenden Grafana-Paket-/INI-/Systempfad und SQLite-Pfad lesen. Erwartet ist
   `/var/lib/grafana/data/grafana.db`; die wirklich verwendete INI entscheidet.
   Bestandsinventur einschließlich anderer Secretstores ohne Wertausgabe prüfen.
   `grafana-key-migration --help` und den exakt gebauten Kandidaten verwenden.
2. Grafana stoppen und prüfen, dass MainPID/ControlPID beide null sind. Bei SQLite keine
   zweite Instanz laufen lassen. Ein privates Verzeichnis mit `umask 077` und Modus `0700`
   anlegen, etwa `/var/backups/grafana-key/<release>`. Den vollständigen Grafana-Datenordner,
   die alte INI und den GC-geschützten alten System-/Recoverybezug sichern. Die konsistente
   SQLite-Sicherung zusätzlich mit `sqlite3 DATENBANK '.backup …/old.db'` erzeugen und
   `PRAGMA integrity_check` prüfen. Altkey geschützt in `old.key` sichern; aus dem hier
   geprüften Altstand übernehmen, niemals aus einer geratenen oder veränderten Konfiguration.
3. Den neuen Schlüssel mit SOPS und `--extract '["grafana"]["secret_key"]'` ohne Terminalausgabe
   in eine private temporäre Datei `new.key` schreiben und nur über den bestehenden
   geschützten SSH-Weg in das private Wartungsverzeichnis übertragen. Beide Keydateien
   müssen reguläre Dateien mit `0600` oder `0400` sein. Den neuen Wert niemals abschreiben.
4. Die Kopie migrieren, mit absoluten privaten Pfaden:

   ```bash
   set -euo pipefail
   umask 077
   grafana-key-migration \
     --source /var/backups/grafana-key/RELEASE/old.db \
     --output /var/backups/grafana-key/RELEASE/new.db \
     --old-key-file /var/backups/grafana-key/RELEASE/old.key \
     --new-key-file /var/backups/grafana-key/RELEASE/new.key
   ```

   Erwartet: `migrated_copy`, vollständige Counts und `new.db.manifest.json`. Bei Fehlern
   keine Aktivierung: unveränderten Altstand starten. Output/Manifest nie wiederverwenden;
   ein zweiter Versuch bekommt einen neuen Dateinamen. Quelle und ihre Dateien erhalten.
5. Noch bei gestopptem Grafana den bisherigen DB-/WAL-/SHM-Satz zusammen in das private
   Wartungsverzeichnis verschieben. Die neue DB mit `grafana:grafana`, `0640` an den
   wirklichen SQLite-Pfad installieren. SHA256 gegen `database_sha256` im Manifest prüfen.
   Das Manifest mit `root:grafana`, `0440` als
   `/var/lib/grafana/runtime-key-ready.json` installieren. Danach den vorgesehenen
   Kandidaten über den Standard-Deployweg aktivieren: SOPS installiert den neuen Key,
   Grafanas Startguard verlangt dessen Fingerprint im Manifest. Ein bloßer Keywechsel
   ohne Manifest wird verweigert.
6. Health und Logs ohne Rohpayloads prüfen. Jede tatsächlich belegte Datasource durch eine
   echte harmlose Abfrage abnehmen; Kontaktpunkte über ihre echte Secretverwendung abnehmen.
   Echte Alarme nur innerhalb des dafür freigegebenen Auftrags zustellen; zum Prüfen isolierte
   Empfänger benutzen. Zugriffsschutz/Loopback/WireGuard bleiben erhalten. Grafana einmal
   neu starten und die Abnahme wiederholen. Optional aktiviertes `academy-prometheus`
   zusätzlich prüfen. Erst dann Releasebericht, aktuelle Pins und Recovery aktualisieren.

Das Ready-Manifest prüft bei späteren Starts den Schlüssel-Fingerprint; sein DB-Hash ist die
Abnahmebindung der initialen Kopie. Grafana verändert die DB später regulär, deshalb prüft
der Startguard deren Dateihash nicht dauerhaft. Die richtige DB/Manifest/Key-Zuordnung ist
Teil des Restorewegs. Der Guard ist kein zusätzlicher Schutz gegen root.

## Rückweg und spätere Backups

Grafana stoppen. Den aktuellen DB-/WAL-/SHM-Satz privat beiseitelegen und **die alte
SQLite-Sicherung mit dem passenden alten System-/Key-Stand gemeinsam** wiederherstellen.
Zur hier vorbereiteten Migration gehört der alte Default aus der gesicherten INI. Den
normalen Altstand ohne Runtime-Key-Import aktivieren; das Ready-Manifest beiseitelegen.
Alternativ bei gleichem getesteten Paket den gesicherten Altkey über dieselbe Laufzeitdatei
und ein dazugehöriges Ready-Manifest benutzen (VM-belegter Rückweg). Vor Wiederöffnung
die Secretverbraucher erneut prüfen. Beim Restore gehen Änderungen seit der Sicherung
verloren; eine beliebige alte Komplettclosure ersetzt keine Prüfung anderer inzwischen
veränderter Dienste oder Datenbankschemata.

Künftige Wiederherstellungen brauchen sowohl DB als auch genau den neuen SOPS-Schlüssel.
Das bisherige öffentliche-Default-Backup bleibt getrennt als geschützter Rückweg erhalten.
Historische Kopien werden durch diese Migration nicht nachträglich sicherer; ihre
Löschung oder Umverschlüsselung ist ein eigener Auftrag. Temporäre unverschlüsselte
Keydateien nach erfolgreicher Sicherung/Abnahme entfernen. Das verschlüsselte Original
und seinen Restorebezug erhalten.

Primärquellen: [Grafana 13.0.7 Encryption-Service](https://github.com/grafana/grafana/blob/v13.0.7/pkg/services/encryption/service/service.go),
[CFB-Provider](https://github.com/grafana/grafana/blob/v13.0.7/pkg/services/encryption/provider/cipher_aescfb.go),
[OSS-Defaultprovider](https://github.com/grafana/grafana/blob/v13.0.7/pkg/services/kmsproviders/defaultprovider/grafana_provider.go),
[DEK-Speicher](https://github.com/grafana/grafana/blob/v13.0.7/pkg/services/secrets/database/database.go),
[Secretmigrationen](https://github.com/grafana/grafana/blob/v13.0.7/pkg/services/secrets/migrator/migrator.go).
