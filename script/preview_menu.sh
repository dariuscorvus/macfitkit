#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${MACFITKIT_BUILD_DIR:-$HOME/Library/Caches/MacFitKit/Monorepo}"
PREVIEW_DIR=$(mktemp -d "$HOME/Library/Caches/MacFitKit/menu-preview.XXXXXX")
SHARED="$ROOT_DIR/Packages/MacFitKitShared/Sources"
for MODULE in MacFitKitCore MacFitKitPlatform; do
  DEPS=(-framework Foundation)
  [[ "$MODULE" == MacFitKitCore ]] || DEPS+=(-lMacFitKitCore)
  swiftc -swift-version 6 -target "$(uname -m)-apple-macosx14.0" -parse-as-library -emit-module -emit-library \
    -I "$PREVIEW_DIR" -L "$PREVIEW_DIR" "${DEPS[@]}" -Xlinker -rpath -Xlinker "$PREVIEW_DIR" \
    -module-name "$MODULE" "$SHARED/$MODULE/"*.swift \
    -emit-module-path "$PREVIEW_DIR/$MODULE.swiftmodule" -o "$PREVIEW_DIR/lib$MODULE.dylib"
done
swiftc -swift-version 6 -parse-as-library -I "$PREVIEW_DIR" -L "$PREVIEW_DIR" -lMacFitKitCore -lMacFitKitPlatform \
  -Xlinker -rpath -Xlinker "$PREVIEW_DIR" "$ROOT_DIR/Tests/Integration/BridgeProbe.swift" -o "$PREVIEW_DIR/Probe"
python3 - "$PREVIEW_DIR" "$BUILD_DIR/Build/Products/Debug/MacFitKit.app" <<'PYTHON'
import plistlib, shutil, subprocess, sys, uuid
from pathlib import Path
root = Path(sys.argv[1]); namespace = 'tech.highbyte.macfitkit.preview.' + uuid.uuid4().hex
for tool in ['focusFrame', 'liveDesktop', 'dockPreview', 'universalPiP']:
    app = root / (tool + '.app'); (app / 'Contents/MacOS').mkdir(parents=True)
    shutil.copy2(root / 'Probe', app / 'Contents/MacOS/Probe')
    with (app / 'Contents/Info.plist').open('wb') as f:
        plistlib.dump(dict(CFBundleIdentifier=namespace+'.'+tool, CFBundleExecutable='Probe', CFBundleName=tool+' Menü-Test', CFBundlePackageType='APPL', LSUIElement=True), f)
    subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
app = root / 'MacFitKit.app'; shutil.copytree(sys.argv[2], app)
p = app / 'Contents/Info.plist'
with p.open('rb') as f: info = plistlib.load(f)
info['CFBundleIdentifier'] = namespace + '.hub'; info['LSUIElement'] = False
with p.open('wb') as f: plistlib.dump(info, f)
subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
# Leave DockPreview stopped so the user can exercise Starten from the real hub UI.
for tool in ['focusFrame', 'liveDesktop', 'universalPiP']:
    subprocess.run(['open','-n',str(root/(tool+'.app')),'--args',tool,namespace,str(root)],check=True)
subprocess.run(['open','-n',str(app),'--args','--ui-preview','--menu-preview',str(root),namespace,'--preview-report',str(root/'window-state.txt')],check=True)
(root/'namespace.txt').write_text(namespace)
print(root)
PYTHON
