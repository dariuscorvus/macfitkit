#!/bin/zsh
set -eu
cd "${0:A:h}/.."
probe_dir=$(mktemp -d "${TMPDIR%/}/LiveDesktop-playback.XXXXXX")
trap 'rm -rf "$probe_dir"' EXIT
swiftc -swift-version 6 -parse-as-library -emit-module -emit-library -module-name LiveDesktopCore Sources/LiveDesktopCore/*.swift -emit-module-path "$probe_dir/LiveDesktopCore.swiftmodule" -o "$probe_dir/libLiveDesktopCore.dylib"
swiftc -swift-version 6 -parse-as-library -I "$probe_dir" -L "$probe_dir" -lLiveDesktopCore -Xlinker -rpath -Xlinker "$probe_dir" Sources/LiveDesktop/DesktopSurface.swift script/tests/PlaybackTests.swift -o "$probe_dir/test-playback"
"$probe_dir/test-playback" "$@" > "$probe_dir/result.txt"
cat "$probe_dir/result.txt"
rg -q '^PASS:' "$probe_dir/result.txt"
