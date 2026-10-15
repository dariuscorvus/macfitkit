import json, os, signal, subprocess, sys, time, uuid
from pathlib import Path
root = Path(sys.argv[1]); channel = 'tech.highbyte.macfitkit.test.' + uuid.uuid4().hex
processes = []
def report(role):
    try: return json.loads((root/(role+'.json')).read_text())
    except (FileNotFoundError, json.JSONDecodeError): return {}
def wait(predicate, description, timeout=8):
    end = time.monotonic()+timeout
    while time.monotonic()<end:
        if predicate(): return
        time.sleep(.1)
    raise AssertionError(description + ': ' + repr({x:report(x) for x in ['hub','focusFrame','liveDesktop','dockPreview','legacy']}))
def start(role, bundle_role=None):
    app = root/(role+'.app'); (app/'Contents/MacOS').mkdir(parents=True, exist_ok=True)
    executable=app/'Contents/MacOS/Probe'
    import shutil, plistlib
    shutil.copy2(root/'Probe', executable)
    identity=channel+'.'+(bundle_role or role)
    with (app/'Contents/Info.plist').open('wb') as f:
        plistlib.dump(dict(CFBundleIdentifier=identity,CFBundleExecutable='Probe',CFBundlePackageType='APPL',LSUIElement=True),f)
    subprocess.run(['codesign','--force','--sign','-',str(app)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    p=subprocess.Popen([str(executable), role, channel, str(root)], stdout=subprocess.DEVNULL,stderr=open(root/(role+'.log'),'a'))
    processes.append(p); return p
def command(action,tool='focusFrame'):
    temp=root/'command.tmp';temp.write_text(json.dumps(dict(sequence=uuid.uuid4().hex,action=action,tool=tool)));temp.replace(root/'command.json')
try:
    focus=start('focusFrame')
    wait(lambda:report('focusFrame').get('visible') is True,'standalone icon missing')
    hub=start('hub')
    wait(lambda:report('focusFrame').get('visible') is False,'handshake failed')
    for role in ['liveDesktop','dockPreview']: start(role)
    wait(lambda:all(report(x).get('visible') is False for x in ['focusFrame','liveDesktop','dockPreview']),'multiple-tool handshake failed')
    command('disable');wait(lambda:report('focusFrame').get('enabled') is False,'pause failed')
    command('settings');wait(lambda:report('focusFrame').get('settingsCount',0)>0,'settings command failed')
    command('enable');wait(lambda:report('focusFrame').get('enabled') is True,'resume failed')
    hub.kill();hub.wait()
    wait(lambda:all(report(x).get('visible') is True for x in ['focusFrame','liveDesktop','dockPreview']),'crash did not restore icons',5)
    hub=start('hub')
    wait(lambda:report('focusFrame').get('visible') is False,'reconnection failed')
    command('stop');hub.wait(timeout=5)
    wait(lambda:all(report(x).get('visible') is True for x in ['focusFrame','liveDesktop','dockPreview']),'graceful stop did not restore icons',3)
    command('status')
    hub=start('hub')
    wait(lambda:report('focusFrame').get('visible') is False,'second reconnection failed')
    command('quit','liveDesktop')
    live=processes[2]
    live.wait(timeout=5)
    # An older tool never acknowledges the protocol and must retain its own icon.
    dock=processes[3];dock.terminate();dock.wait(timeout=5)
    legacy=start('legacy','dockPreview')
    wait(lambda:report('legacy').get('visible') is True,'legacy icon missing')
    command('settings','dockPreview')
    wait(lambda:bool(report('hub').get('error')),'legacy timeout was not reported',9)
    assert legacy.poll() is None
    print('PASS: standalone, both launch orders, 3 tools, acknowledged hiding, pause/resume/settings/quit, crash fallback, graceful fallback, restart and legacy timeout; isolated notification channel and bundle IDs')
finally:
    for p in processes:
        if p.poll() is None:
            p.terminate()
            try:p.wait(timeout=3)
            except subprocess.TimeoutExpired:p.kill();p.wait()
