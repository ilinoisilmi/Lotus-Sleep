#!/usr/bin/env python3
"""Structural packaging audit, not an iOS build or an API type check."""
from pathlib import Path
import json,plistlib,hashlib,re,subprocess,sys,wave,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
checks=[]
def check(condition,label):
 if not condition:raise AssertionError(label)
 checks.append(label)
for name in ['README.md','WINDOWS_START_HERE.md','ARCHITECTURE.md','ADDING_FEATURES.md','Docs/BUILD_AND_INSTALL.md','Docs/FEATURE_STATUS.md','Docs/DATA_FORMATS.md','Docs/DEVICE_TESTING.md','Docs/SOURCES.md','Docs/TEST_RESULTS.md']:
 check((ROOT/name).is_file(),f'Required document exists: {name}')
plists={}
for path in list((ROOT/'Config').glob('*.plist'))+list((ROOT/'Config').glob('*.entitlements'))+list((ROOT/'App/Resources').glob('*.xcprivacy')):
 plists[path.name]=plistlib.loads(path.read_bytes());checks.append(f'Valid plist: {path.name}')
info=plists['App-Info.plist']
for key in ['NSMicrophoneUsageDescription','NSMotionUsageDescription','NSHealthShareUsageDescription','NSAlarmKitUsageDescription']:
 check(bool(info.get(key)),f'Purpose string: {key}')
check('NSHealthUpdateUsageDescription' not in info,'Health write permission is not requested')
check(info.get('UIBackgroundModes')==['audio'],'Background mode is audio only')
check(info.get('UIApplicationSceneManifest',{}).get('UIApplicationSupportsMultipleScenes') is False,'SwiftUI single-window scene manifest')
check(not plists['Basic.entitlements'],'Basic has no custom entitlements')
check(plists['Health.entitlements'].get('com.apple.developer.healthkit') is True,'Health entitlement enabled only for optional scheme')
check(plists['Health.entitlements']['com.apple.security.application-groups']==plists['Widget.entitlements']['com.apple.security.application-groups'],'App Group strings match')
base=(ROOT/'Config/Base.xcconfig').read_text()
check('IPHONEOS_DEPLOYMENT_TARGET = 17.0' in base,'Deployment target is iOS 17')
pbx=ROOT/'LumaSleep.xcodeproj/project.pbxproj';before=pbx.read_bytes()
subprocess.run([sys.executable,str(ROOT/'Scripts/generate_project.py')],check=True,stdout=subprocess.PIPE,text=True)
check(pbx.read_bytes()==before,'Xcode project regeneration is deterministic and current')
text=pbx.read_text()
check('path = "App/Resources/SleepSounds";' in text,'Bundled sleep sounds included in Xcode')
for name in ['white','pink','brown','rain','ocean','fan']:
 with wave.open(str(ROOT/f'App/Resources/SleepSounds/{name}.wav')) as sound:
  check(sound.getnchannels()==1 and sound.getsampwidth()==2 and sound.getframerate()==22050 and sound.getnframes()==661500,f'Valid 30-second PCM sound: {name}')
art=ET.parse(ROOT/'Design/Companions.svg').getroot()
check(len(art.findall('{http://www.w3.org/2000/svg}g'))==20,'Companion sheet has four animals with five stages')
check((ROOT/'App/Resources/Assets.xcassets/CompanionSheet.imageset/CompanionSheet.pdf').read_bytes().startswith(b'%PDF-'),'Companion vector asset is a PDF')
check('MARKETING_VERSION = 1.3' in base and 'CURRENT_PROJECT_VERSION = 4' in base,'Lotus release version is 1.3 build 4')
check(info['CFBundleDisplayName']=='Lotus Sleep','Installed display name is Lotus Sleep')
check('LUMA_BUNDLE_ID = com.ilmi.lumasleep' in base,'Existing installation identifier preserved')
for folder in ['App','Core/Sources/LumaCore']:
 for source in (ROOT/folder).rglob('*.swift'):
  check('path = '+json.dumps(str(source.relative_to(ROOT)))+';' in text,f'Xcode includes {source.relative_to(ROOT)}')
for name in ['LumaBasic','LumaHealth']:
 scheme=ET.parse(ROOT/f'LumaSleep.xcodeproj/xcshareddata/xcschemes/{name}.xcscheme').getroot()
 check(scheme.find('.//BuildableReference').attrib['BlueprintName']==name,f'Scheme references {name}')
for manifest in (ROOT/'App/Resources/Assets.xcassets').rglob('Contents.json'):
 data=json.loads(manifest.read_text())
 for item in data.get('images',[]):
  if 'filename' in item:check((manifest.parent/item['filename']).is_file(),f'Asset exists: {item["filename"]}')
for file in (ROOT/'Examples').glob('*.json'):json.loads(file.read_text());checks.append(f'Valid example JSON: {file.name}')
for md in ROOT.rglob('*.md'):
 if '.build' in md.parts:continue
 for link in re.findall(r'\]\(([^)]+)\)',md.read_text()):
  if not re.match(r'^[a-z]+:',link) and not link.startswith('#'):
   check((md.parent/link.split('#')[0]).exists(),f'Local doc link resolves: {md.name} -> {link}')
print(f'PASS: {len(checks)} structural checks')
for c in checks:print('PASS '+c)
