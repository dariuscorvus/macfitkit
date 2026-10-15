#!/usr/bin/env python3
"""Inspect the actual app inside a release DMG, including its trust state."""
import argparse
import plistlib
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('dmg', type=Path)
parser.add_argument('--allow-unnotarized', action='store_true')
parser.add_argument('--smoke-copy', type=Path)
args = parser.parse_args()
cache = Path.home() / 'Library/Caches/FocusFrame'
cache.mkdir(parents=True, exist_ok=True)
subprocess.run(['codesign', '--verify', '--strict', str(args.dmg)], check=True)
subprocess.run(['hdiutil', 'verify', str(args.dmg)], check=True, stdout=subprocess.DEVNULL)
lines = []
with tempfile.TemporaryDirectory(prefix='release-mount.', dir=cache) as directory:
    mount = Path(directory)
    attached = False
    try:
        subprocess.run(['hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', str(mount), str(args.dmg)],
                       check=True, stdout=subprocess.DEVNULL)
        attached = True
        app = mount / 'FocusFrame.app'
        binary = app / 'Contents/MacOS/FocusFrame'
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
        architectures = subprocess.check_output(['xcrun', 'lipo', str(binary), '-archs'], text=True).strip()
        assert set(architectures.split()) == {'arm64', 'x86_64'}, architectures
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        assert info['LSMinimumSystemVersion'] == '14.0'
        assert info['CFBundleIdentifier'] == 'de.highbytetech.FocusFrame'
        signature = subprocess.run(['codesign', '-d', '--verbose=4', str(app)],
                                   capture_output=True, text=True, check=True).stderr
        assert 'Authority=Developer ID Application:' in signature and '(runtime)' in signature
        load = subprocess.check_output(['xcrun', 'otool', '-l', str(binary)], text=True)
        minimums = [row.strip() for row in load.splitlines() if row.strip().startswith('minos ')]
        assert minimums == ['minos 14.0', 'minos 14.0'], minimums
        gate = subprocess.run(['spctl', '--assess', '--type', 'execute', '--verbose=4', str(app)],
                              capture_output=True, text=True)
        assessment = gate.stdout + gate.stderr
        if gate.returncode != 0:
            assert args.allow_unnotarized and 'source=Unnotarized Developer ID' in assessment, assessment
        lines = ['DMG and included app signatures verified strictly.',
                 f'Version: {info["CFBundleShortVersionString"]}', f'Architectures: {architectures}',
                 'Minimum macOS: 14.0 in both executable slices', signature,
                 'Gatekeeper assessment:', assessment]
        if args.smoke_copy:
            assert not args.smoke_copy.exists(), 'Smoke-copy destination already exists'
            subprocess.run(['ditto', str(app), str(args.smoke_copy)], check=True)
            subprocess.run(['codesign', '--verify', '--deep', '--strict', str(args.smoke_copy)], check=True)
    finally:
        if attached:
            subprocess.run(['hdiutil', 'detach', str(mount)], check=True, stdout=subprocess.DEVNULL)
print('\n'.join(lines))
