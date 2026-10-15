#!/usr/bin/env python3
"""Validate checked-in Xcode source membership and shared schemes without Xcode."""
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
project = root / 'FocusFrame.xcodeproj'
data = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(project / 'project.pbxproj')]))
objects = data['objects']
project_object = objects[data['rootObject']]
expected = {
    'FocusFrame': 'Sources/FocusFrame',
    'FocusFrameCore': 'Sources/FocusFrameCore',
    'FocusFrameFixture': 'Sources/FocusFrameFixture',
    'FocusFrameCoreTests': 'Tests/FocusFrameCoreTests',
}
targets = {objects[key]['name']: key for key in project_object['targets']}
assert set(targets) == set(expected), 'Unexpected or missing targets'
for name, folder in expected.items():
    target = objects[targets[name]]
    phases = [objects[key] for key in target['buildPhases']]
    sources = next(p for p in phases if p['isa'] == 'PBXSourcesBuildPhase')
    actual = {objects[objects[key]['fileRef']]['path'] for key in sources['files']}
    wanted = {str(p.relative_to(root)) for p in (root / folder).glob('*.swift')}
    assert actual == wanted, f'{name}: source membership differs: {actual ^ wanted}'
    if name in ('FocusFrame', 'FocusFrameCoreTests'):
        deps = [objects[key]['target'] for key in target['dependencies']]
        assert targets['FocusFrameCore'] in deps, f'{name}: missing core dependency'
        libraries = next(p for p in phases if p['isa'] == 'PBXFrameworksBuildPhase')
        assert objects[targets['FocusFrameCore']]['productReference'] in [objects[k]['fileRef'] for k in libraries['files']]
for name in ('FocusFrame', 'FocusFrameFixture'):
    scheme = ET.parse(project / 'xcshareddata/xcschemes' / f'{name}.xcscheme')
    for reference in scheme.findall('.//BuildableReference'):
        assert reference.attrib['BlueprintIdentifier'] in targets.values(), 'Invalid scheme target reference'
    assert scheme.find('./LaunchAction/BuildableProductRunnable/BuildableReference').attrib['BlueprintName'] == name
    if name == 'FocusFrame':
        assert scheme.find('./TestAction/Testables/TestableReference/BuildableReference').attrib['BlueprintName'] == 'FocusFrameCoreTests'
print('Xcode project structure, source membership and shared schemes valid (not an Xcode build).')
