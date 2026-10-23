#!/usr/bin/env python3
"""Build and verify notarized, MIT-licensed MacFitKit preview downloads."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
APPS = {
    'FocusFrame': 'de.highbytetech.FocusFrame',
    'LiveDesktop': 'tech.highbyte.LiveDesktop.prototype',
    'DockPreview': 'tech.highbyte.macfitkit.DockPreview',
    'UniversalPiP': 'tech.highbyte.macfitkit.UniversalPiP',
    'FolderIconer': 'tech.highbyte.macfitkit.FolderIconer',
    'MacFitKit': 'tech.highbyte.macfitkit.Menu',
}
REPO = 'dariuscorvus/macfitkit'


def command(args, log_dir=None, env=None):
    result = subprocess.run([str(x) for x in args], cwd=ROOT, env=env,
                            capture_output=True, text=True)
    if log_dir:
        log_dir.mkdir(parents=True, exist_ok=True)
        log = log_dir / (Path(str(args[0])).name + '-' + uuid.uuid4().hex[:8] + '.log')
        log.write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed; ' + (f'see {log}' if log_dir else result.stderr))
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def notarize(path, kind, folder, profile):
    logs = folder / '.logs'
    response = command(['xcrun', 'notarytool', 'submit', path, '--keychain-profile', profile,
                        '--no-wait', '--output-format', 'json'], logs)
    info = json.loads(response.stdout)
    (folder / (kind + '-submission.json')).write_text(response.stdout)
    submission = info['id']
    print(f'{folder.name}: {kind} submitted to Apple.', flush=True)
    deadline = time.monotonic() + 1200
    while time.monotonic() < deadline:
        # A timeout leaves the submission intact; query its authoritative state next.
        subprocess.run(['xcrun', 'notarytool', 'wait', submission, '--keychain-profile', profile,
                        '--timeout', '30s', '--output-format', 'json'], capture_output=True, text=True)
        result = command(['xcrun', 'notarytool', 'info', submission, '--keychain-profile', profile,
                          '--output-format', 'json'], logs)
        status = json.loads(result.stdout)['status']
        (folder / (kind + '-status.json')).write_text(result.stdout)
        if status == 'Accepted':
            print(f'{folder.name}: {kind} accepted by Apple.', flush=True)
            return submission
        if status == 'Invalid':
            command(['xcrun', 'notarytool', 'log', submission, '--keychain-profile', profile], logs)
            raise RuntimeError(f'{folder.name}: Apple rejected {kind}; see {logs}')
    raise RuntimeError(f'{folder.name}: {kind} still pending; submission {submission} is recorded')


def verify_app(app, name, license_bytes, metadata, logs):
    assert (app / 'Contents/Resources/LICENSE').read_bytes() == license_bytes
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert info['CFBundleIdentifier'] == APPS[name]
    assert info['CFBundleShortVersionString'] == metadata['version']
    assert info['CFBundleVersion'] == metadata['build']
    assert info['LSMinimumSystemVersion'] == metadata['minimumMacOS']
    binary = app / 'Contents/MacOS' / name
    assert digest(binary) == metadata['binarySHA256']
    assert (app / 'Contents/Resources/SourceRevision.txt').read_text().strip() == metadata['sourceRevision']
    assert set(command(['lipo', '-archs', binary], logs).stdout.split()) == {'arm64', 'x86_64'}
    load = command(['otool', '-l', binary], logs).stdout
    minimums = [line.strip().split()[1] for line in load.splitlines() if line.strip().startswith('minos ')]
    assert minimums == [metadata['minimumMacOS']] * 2, minimums
    command(['codesign', '--verify', '--deep', '--strict', app], logs)
    signature = command(['codesign', '-d', '--verbose=4', app], logs)
    assert 'Authority=Developer ID Application:' in signature.stderr and '(runtime)' in signature.stderr
    command(['xcrun', 'stapler', 'validate', app], logs)
    if name == 'MacFitKit':
        nested = metadata.get('bundledTools', [])
        assert {item['app'] for item in nested} == set(APPS) - {'MacFitKit'}
        for item in nested:
            verify_app(app / 'Contents/Resources/ToolPayloads' / (item['app'] + '.app'),
                       item['app'], license_bytes, item, logs)
    gate = command(['spctl', '--assess', '--type', 'execute', '--verbose=4', app], logs)
    assert 'source=Notarized Developer ID' in gate.stderr


def package(name, args, output, build_dir, identity, revision, license_bytes, tool_metadata=None):
    folder = output / name
    folder.mkdir()
    logs = folder / '.logs'
    with tempfile.TemporaryDirectory(prefix=name + '-', dir=output) as temp:
        temp = Path(temp)
        zip_root = temp / 'zip-root'
        zip_root.mkdir()
        app = zip_root / (name + '.app')
        command(['ditto', build_dir / 'Build/Products/Release' / (name + '.app'), app], logs)
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        assert info['CFBundleIdentifier'] == APPS[name]
        metadata = dict(app=name, version=info['CFBundleShortVersionString'], build=info['CFBundleVersion'],
                        bundleIdentifier=APPS[name], minimumMacOS=info['LSMinimumSystemVersion'],
                        sourceRevision=revision, binarySHA256=digest(app / 'Contents/MacOS' / name),
                        architectures=['arm64', 'x86_64'], license='MIT', licenseSHA256=hashlib.sha256(license_bytes).hexdigest(),
                        signing='Developer ID Application', hardenedRuntime=True, notarized=True, stapled=True, prerelease=True)
        metadata['tag'] = f"{name.lower()}-v{metadata['version']}-preview.{args.preview}"
        resources = app / 'Contents/Resources'
        resources.mkdir(exist_ok=True)
        (resources / 'LICENSE').write_bytes(license_bytes)
        (resources / 'SourceRevision.txt').write_text(revision + '\n')
        if name == 'MacFitKit':
            assert tool_metadata and {item['app'] for item in tool_metadata} == set(APPS) - {'MacFitKit'}
            payloads = resources / 'ToolPayloads'
            # Embed the finalized, stapled packages, not the raw Xcode build products.
            if payloads.exists():
                shutil.rmtree(payloads)
            payloads.mkdir()
            for item in tool_metadata:
                archive = next(output / item['app'] / file for file in item['files'] if file.endswith('.zip'))
                assert digest(archive) == item['files'][archive.name]
                extracted_tool = temp / ('payload-' + item['app'])
                command(['ditto', '-x', '-k', archive, extracted_tool], logs)
                source_tool = extracted_tool / (item['app'] + '.app')
                verify_app(source_tool, item['app'], license_bytes, item, logs)
                embedded = payloads / source_tool.name
                command(['ditto', source_tool, embedded], logs)
                verify_app(embedded, item['app'], license_bytes, item, logs)
            metadata['bundledTools'] = tool_metadata
        (zip_root / 'LICENSE').write_bytes(license_bytes)
        (folder / 'LICENSE.txt').write_bytes(license_bytes)
        installation = f"""{name} {metadata['version']} – Preview {args.preview}

macOS {metadata['minimumMacOS']} oder neuer; Apple Silicon oder Intel.
Mit Developer ID signiert und von Apple notarisiert. Tickets sind an App und DMG
angeheftet. Beim ersten Start kann macOS die übliche Download-Bestätigung verlangen.

Installation: Die App nach Programme oder in den eigenen Programme-Ordner kopieren.
Update: Vorhandene App und Einstellungen sichern, die App beenden und am bisherigen
Ort ersetzen. Keine zweite Kopie installieren. Ein Wechsel der lokalen Signatur
kann eine erneute Freigabe durch macOS erfordern. Gatekeeper nicht global abschalten.

Ab MacFitKit 0.4.4 können die Tools im Tool-Katalog installiert, aktualisiert
und deinstalliert werden, ab MacFitKit 0.5.0 auch FolderIconer. Updates und Deinstallationen sichern die alte App samt
exportierten Einstellungen; vorhandene Daten bleiben erhalten. Die Wiederherstellung
aus einem Backup ist derzeit manuell. Die App-Versionen entscheiden über Updates,
nicht die Preview-Nummer; gleich versionierte Tools werden nicht erneut angeboten.

Die Apps sind über ihre Menüleistensymbole erreichbar; FolderIconer ist eine
normale App mit Fenster und Dock-Symbol. MacFitKit ist optional;
die anderen Tools bleiben eigenständig nutzbar. Autostart wird je App unter
Allgemein → Beim Anmelden starten eingestellt.

Lizenz: MIT. Der vollständige Text liegt als LICENSE neben der App sowie unter
Contents/Resources/LICENSE im App-Bundle und als LICENSE.txt im GitHub-Release.
Quelle: https://github.com/{REPO}
Revision: {revision}
"""
        (zip_root / 'Installation.txt').write_text(installation)
        (folder / 'Installation.txt').write_text(installation)
        frameworks = app / 'Contents/Frameworks'
        if frameworks.exists():
            for extension in ['*.dylib', '*.framework']:
                for child in sorted(frameworks.rglob(extension), key=lambda p: len(p.parts), reverse=True):
                    command(['codesign', '--force', '--timestamp', '--options', 'runtime', '--sign', identity, child], logs)
        command(['codesign', '--force', '--timestamp', '--options', 'runtime', '--sign', identity, app], logs)
        command(['codesign', '--verify', '--deep', '--strict', app], logs)
        # Signing updates the Mach-O signature blob; compare the finalized binary.
        metadata['binarySHA256'] = digest(app / 'Contents/MacOS' / name)
        upload = temp / 'app-notary.zip'
        command(['ditto', '-c', '-k', '--sequesterRsrc', zip_root, upload], logs)
        metadata['appNotarizationID'] = notarize(upload, 'app', folder, args.notary_profile)
        command(['xcrun', 'stapler', 'staple', app], logs)
        verify_app(app, name, license_bytes, metadata, logs)
        stem = f"{name}-{metadata['version']}-preview.{args.preview}-universal"
        archive, dmg = folder / (stem + '.zip'), folder / (stem + '.dmg')
        command(['ditto', '-c', '-k', '--sequesterRsrc', zip_root, archive], logs)
        command(['unzip', '-tq', archive], logs)
        image = temp / 'image'
        command(['ditto', zip_root, image], logs)
        (image / 'Applications').symlink_to('/Applications')
        command(['hdiutil', 'create', '-volname', f"{name} Preview {args.preview}", '-srcfolder', image,
                 '-fs', 'HFS+', '-format', 'UDZO', dmg], logs)
        command(['codesign', '--timestamp', '--sign', identity, dmg], logs)
        metadata['dmgNotarizationID'] = notarize(dmg, 'dmg', folder, args.notary_profile)
        command(['xcrun', 'stapler', 'staple', dmg], logs)
        command(['xcrun', 'stapler', 'validate', dmg], logs)
        command(['codesign', '--verify', '--strict', dmg], logs)
        command(['hdiutil', 'verify', dmg], logs)
        command(['spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose=4', dmg], logs)
        mount = temp / 'mount'
        mount.mkdir()
        attached = False
        try:
            command(['hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', mount, dmg], logs)
            attached = True
            assert (mount / 'LICENSE').read_bytes() == license_bytes
            assert (mount / 'Installation.txt').read_text() == installation
            verify_app(mount / (name + '.app'), name, license_bytes, metadata, logs)
        finally:
            if attached:
                command(['hdiutil', 'detach', mount], logs)
        extracted = temp / 'zip-check'
        command(['ditto', '-x', '-k', archive, extracted], logs)
        assert (extracted / 'LICENSE').read_bytes() == license_bytes
        assert (extracted / 'Installation.txt').read_text() == installation
        verify_app(extracted / (name + '.app'), name, license_bytes, metadata, logs)
        metadata['files'] = {path.name: digest(path) for path in [archive, dmg]}
        (folder / 'Release-info.json').write_text(json.dumps(metadata, indent=2) + '\n')
        files = [archive, dmg, folder / 'LICENSE.txt', folder / 'Installation.txt', folder / 'Release-info.json']
        (folder / 'SHA256SUMS.txt').write_text(''.join(f'{digest(path)}  {path.name}\n' for path in files))
        notes = f"""{name} {metadata['version']} · Preview {args.preview}

Diese Ausgabe enthält die vollständige **MIT-Lizenz** im App-Bundle und jeweils
neben der App im DMG/ZIP. `LICENSE.txt` liegt außerdem direkt im Release.

- Developer-ID-signierte Universal-App für Apple Silicon und Intel, macOS {metadata['minimumMacOS']}+.
- App und DMG von Apple akzeptiert; Tickets angeheftet und mit Gatekeeper geprüft.
- Lizenzbytes, Signaturen und Tickets der tatsächlichen Apps aus DMG und ZIP kontrolliert.
- Herkunft: [`{revision[:12]}`](https://github.com/{REPO}/commit/{revision}).
- Installation und Prüfsummen: `Installation.txt`, `Release-info.json`, `SHA256SUMS.txt`.

Neu in Preview 6:
- FolderIconer 0.1.0 (Build 1), neu: Ordnersymbole aus Ebenen gestalten – Ordnerbasis,
  Bild, Text, Emoji, SF Symbol, SVG/PDF und Formen, mit Kontur, Schatten und Leuchten.
  Symbole auf Ordner anwenden und das vorherige Symbol wiederherstellen, auch im Finder
  über Dienste „Customize Icon…“ und „Restore Folder Icon“. Die Oberfläche ist englisch.
- MacFitKit 0.5.0 (Build 9): FolderIconer im Tool-Katalog installieren, öffnen,
  aktualisieren und deinstallieren. Laufende Dock-Apps werden für Updates regulär beendet.
- Der Hub enthält dieselben fertig notarisierten Tools wie die Einzelpakete.
- FocusFrame 0.9.0 (Build 9), LiveDesktop 0.4.0 (Build 5), DockPreview 0.2.0 (Build 2)
  und UniversalPiP 0.1.2 (Build 3) behalten ihre Bundle-Versionen. Eine neue
  Preview-Nummer allein löst kein Update aus. MacFitKit selbst wird über seinen Download aktualisiert.
- FolderIconer-Grenzen: iCloud Drive synchronisiert eigene Ordnersymbole nicht;
  SVG ist unter macOS 14 und 15 nicht geprüft.

Die README und GitHub-Formulare helfen bei Einrichtung, Fehlern und Wünschen.
FocusFrame verdeckt Rahmen, Leuchten und Schatten bei davorliegenden Fenstern.
Bildschirmgroße transparente Dock-Flächen blenden die Effekte nicht mehr aus.
Native Kontextmenüs liegen vor den Effekten; ihre systemeigene Materialtransparenz
kann weiterhin weichgezeichnete Effektfarben zeigen. Dieses Verhalten ist akzeptiert.
Sichtbare Tests mit überlappenden Fenstern, Freilegen und nativen/eigenen Kontextmenüs
sind [dokumentiert](https://github.com/{REPO}/blob/{revision}/docs/focusframe-occlusion-plan.md).
Offene Plattform-/Barrierefreiheits- und UniversalPiP-Langzeitprüfungen bleiben
[in der Validierungsdokumentation](https://github.com/{REPO}/blob/{revision}/docs/validation-monorepo.md)
und [PiP-Testmatrix](https://github.com/{REPO}/blob/{revision}/docs/universal-pip.md) dokumentiert.
Diese Veröffentlichung verändert keine installierten Apps oder Einstellungen.
"""
        (folder / 'Release-notes.md').write_text(notes)
    print(f'{name}: DMG and ZIP verified, including both MIT notices.', flush=True)
    return metadata


def publish(metadata, output):
    folder = output / metadata['app']
    files = [folder / name for name in metadata['files']]
    files += [folder / name for name in ['LICENSE.txt', 'Installation.txt', 'Release-info.json', 'SHA256SUMS.txt']]
    logs = folder / '.logs'
    # Never overwrite a pre-existing tag or release, including an outcome from a previous run.
    exists = subprocess.run(['gh', 'api', f"repos/{REPO}/git/ref/tags/{metadata['tag']}"], capture_output=True)
    if exists.returncode == 0:
        raise RuntimeError('Refusing to reuse existing tag: ' + metadata['tag'])
    command(['gh', 'release', 'create', metadata['tag'], '--repo', REPO, '--target', metadata['sourceRevision'],
             '--title', f"{metadata['app']} {metadata['version']} · Preview {ARGS.preview} (MIT, notarisiert)",
             '--notes-file', folder / 'Release-notes.md', '--prerelease', '--latest=false', *files], logs)
    release = json.loads(command(['gh', 'api', f"repos/{REPO}/releases/tags/{metadata['tag']}"], logs).stdout)
    assert release['prerelease'] and not release['draft']
    commit = json.loads(command(['gh', 'api', f"repos/{REPO}/commits/{metadata['tag']}"], logs).stdout)
    assert commit['sha'] == metadata['sourceRevision']
    assets = {item['name']: item for item in release['assets']}
    assert set(assets) == {path.name for path in files}
    for path in files:
        assert assets[path.name]['size'] == path.stat().st_size
        if assets[path.name].get('digest'):
            assert assets[path.name]['digest'] == 'sha256:' + digest(path)
    print('Published and verified: ' + release['html_url'], flush=True)
    return dict(app=metadata['app'], tag=metadata['tag'], url=release['html_url'], sourceRevision=metadata['sourceRevision'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', choices=['all', *APPS], nargs='?', default='all')
    parser.add_argument('--preview', type=int, required=True)
    parser.add_argument('--notary-profile', required=True)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--build-dir', type=Path, default=Path.home() / 'Library/Caches/MacFitKit/ReleaseBuild')
    parser.add_argument('--signing-identity')
    parser.add_argument('--publish', action='store_true')
    ARGS = parser.parse_args()
    assert ARGS.preview > 0
    assert not command(['git', 'status', '--porcelain']).stdout.strip(), 'Release source must be clean'
    revision = command(['git', 'rev-parse', 'HEAD']).stdout.strip()
    license_bytes = (ROOT / 'LICENSE').read_bytes()
    assert license_bytes.startswith(b'MIT License\n')
    identity = ARGS.signing_identity
    if not identity:
        identities = command(['security', 'find-identity', '-v', '-p', 'codesigning']).stdout
        identity = re.search(r'\d+\) ([A-F0-9]{40}) "Developer ID Application:', identities).group(1)
    output = (ARGS.output or Path.home() / f'Library/Caches/MacFitKit/Releases/{revision[:12]}-preview.{ARGS.preview}').resolve()
    output.mkdir(parents=True, mode=0o700, exist_ok=False)
    env = dict(os.environ, MACFITKIT_SIGNING_IDENTITY=identity, MACFITKIT_BUILD_DIR=str(ARGS.build_dir.resolve()))
    command(['bash', ROOT / 'script/build.sh', ARGS.app, 'Release'], output / '.logs', env)
    names = list(APPS) if ARGS.app in ['all', 'MacFitKit'] else [ARGS.app]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        metadata = list(pool.map(lambda name: package(name, ARGS, output, ARGS.build_dir.resolve(), identity, revision, license_bytes),
                                 [name for name in names if name != 'MacFitKit']))
    if 'MacFitKit' in names:
        metadata.append(package('MacFitKit', ARGS, output, ARGS.build_dir.resolve(), identity, revision, license_bytes,
                                tool_metadata=list(metadata)))
    (output / 'manifest.json').write_text(json.dumps(metadata, indent=2))
    if ARGS.publish:
        published = []
        for item in metadata:
            if ARGS.app != 'all' and item['app'] != ARGS.app:
                continue
            published.append(publish(item, output))
            (output / 'published.json').write_text(json.dumps(published, indent=2))
    print('Release output: ' + str(output), flush=True)
