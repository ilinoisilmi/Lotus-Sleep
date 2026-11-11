#!/usr/bin/env python3
"""Deterministic, dependency-free Xcode project generator. Run from any directory."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
objects={}
def uid(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def add(key,isa,**props):
 i=uid(key);objects[i]={'isa':isa,**props};return i
def ref(path,kind):return add('file:'+path,'PBXFileReference',lastKnownFileType=kind,path=path,sourceTree='<group>')
def build_ref(key,r,attrs=None):
 return add('build:'+key,'PBXBuildFile',fileRef=r,**({'settings':{'ATTRIBUTES':attrs}} if attrs else {}))
def array(v):return '('+', '.join(fmt(x) for x in v)+', )' if v else '()'
def fmt(v):
 if isinstance(v,dict):return '{ '+ ' '.join(str(k)+' = '+fmt(value)+';' for k,value in v.items())+' }'
 if isinstance(v,list):return array(v)
 if isinstance(v,int):return str(v)
 if str(v) in objects:return str(v)
 return json.dumps(str(v))
app_paths=sorted(str(p.relative_to(ROOT)) for base in ['App','Core/Sources/LumaCore'] for p in (ROOT/base).rglob('*.swift'))
app_refs=[ref(p,'sourcecode.swift') for p in app_paths]
widget=ref('Widget/LumaWidget.swift','sourcecode.swift')
ui=ref('Tests/LumaUITests.swift','sourcecode.swift')
assets=ref('App/Resources/Assets.xcassets','folder.assetcatalog')
sleep_sounds=ref('App/Resources/SleepSounds','folder')
privacy=ref('App/Resources/PrivacyInfo.xcprivacy','text.xml')
base=ref('Config/Base.xcconfig','text.xcconfig')
config_refs=[base]+[ref('Config/'+p,'text.plist.xml' if p.endswith(('.plist','.entitlements')) else 'text.xcconfig') for p in ['App-Info.plist','Widget-Info.plist','Basic.entitlements','Health.entitlements','Widget.entitlements','User.xcconfig.example']]
products=[]
target_ids={name:uid('target:'+name) for name in ['LumaBasic','LumaHealth','LumaWidget','LumaUITests']}
product_ids={name:add('product:'+name,'PBXFileReference',explicitFileType=kind,path=product,sourceTree='BUILT_PRODUCTS_DIR',includeInIndex=0) for name,kind,product in [('LumaBasic','wrapper.application','LumaSleep.app'),('LumaHealth','wrapper.application','LumaSleep.app'),('LumaWidget','wrapper.app-extension','LumaWidget.appex'),('LumaUITests','wrapper.cfbundle','LumaUITests.xctest')]}
def configs(name,settings,base_ref=False):
 ids=[]
 for mode in ['Debug','Release']:
  values=dict(settings);values.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym'})
  if mode=='Debug':values['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='$(inherited) DEBUG '+values.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS','')
  ids.append(add('config:'+name+mode,'XCBuildConfiguration',buildSettings=values,name=mode,**({'baseConfigurationReference':base} if base_ref else {})))
 return add('configlist:'+name,'XCConfigurationList',buildConfigurations=ids,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
project_id=uid('project')
def dependency(parent,child):
 proxy=add('proxy:'+parent+child,'PBXContainerItemProxy',containerPortal=project_id,proxyType=1,remoteGlobalIDString=target_ids[child],remoteInfo=child)
 return add('dep:'+parent+child,'PBXTargetDependency',target=target_ids[child],targetProxy=proxy)
for name in target_ids:
 is_app=name in ['LumaBasic','LumaHealth']; is_widget=name=='LumaWidget'; is_ui=name=='LumaUITests'
 source_refs=app_refs if is_app else [widget] if is_widget else [ui]
 source_phase=add('sources:'+name,'PBXSourcesBuildPhase',buildActionMask=2147483647,files=[build_ref(name+str(i),r) for i,r in enumerate(source_refs)],runOnlyForDeploymentPostprocessing=0)
 res_phase=add('resources:'+name,'PBXResourcesBuildPhase',buildActionMask=2147483647,files=[build_ref(name+'resource'+str(i),r) for i,r in enumerate([assets,privacy,sleep_sounds] if is_app else [privacy] if is_widget else [])],runOnlyForDeploymentPostprocessing=0)
 frameworks=add('frameworks:'+name,'PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
 phases=[source_phase,frameworks,res_phase];deps=[]
 settings={'PRODUCT_NAME':'LumaSleep' if is_app else name,'PRODUCT_BUNDLE_IDENTIFIER':'$(LUMA_BUNDLE_ID)' + ('.widget' if is_widget else '.uitests' if is_ui else ''),'SDKROOT':'iphoneos','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks'],'GENERATE_INFOPLIST_FILE':'NO','CODE_SIGN_STYLE':'Automatic'}
 if is_app:
  settings.update({'INFOPLIST_FILE':'Config/App-Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/'+('Health' if name=='LumaHealth' else 'Basic')+'.entitlements','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'$(inherited)'+(' HEALTH_ENABLED' if name=='LumaHealth' else '')})
 if is_widget:settings.update({'INFOPLIST_FILE':'Config/Widget-Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/Widget.entitlements','APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES'})
 if is_ui:settings.update({'GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'LumaBasic'});deps.append(dependency(name,'LumaBasic'))
 if name=='LumaHealth':
  deps.append(dependency(name,'LumaWidget'))
  phases.append(add('embed:'+name,'PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=[build_ref('embedwidget',product_ids['LumaWidget'],['RemoveHeadersOnCopy'])],name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0))
 add('target:'+name,'PBXNativeTarget',buildConfigurationList=configs(name,settings),buildPhases=phases,buildRules=[],dependencies=deps,name=name,productName=settings['PRODUCT_NAME'],productReference=product_ids[name],productType='com.apple.product-type.application' if is_app else 'com.apple.product-type.app-extension' if is_widget else 'com.apple.product-type.bundle.ui-testing')
app_group=add('group:app','PBXGroup',children=app_refs+[widget,ui,assets,privacy,sleep_sounds],name='Sources',sourceTree='<group>')
config_group=add('group:config','PBXGroup',children=config_refs,name='Configuration',sourceTree='<group>')
product_group=add('group:products','PBXGroup',children=list(product_ids.values()),name='Products',sourceTree='<group>')
main=add('group:main','PBXGroup',children=[app_group,config_group,product_group],sourceTree='<group>')
project_config=configs('project',{'CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','ENABLE_TESTABILITY':'YES'},True)
add('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2700','TargetAttributes':{target_ids[n]:{'CreatedOnToolsVersion':'27.2'} for n in target_ids}},buildConfigurationList=project_config,compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=main,productRefGroup=product_group,projectDirPath='',projectRoot='',targets=list(target_ids.values()))
project=ROOT/'LumaSleep.xcodeproj';project.mkdir(exist_ok=True)
text='// !$*UTF8*$!\n{\n archiveVersion = 1;\n classes = {};\n objectVersion = 56;\n objects = {\n'
for key,obj in sorted(objects.items()):text+='  '+key+' = '+fmt(obj)+';\n'
text+=' };\n rootObject = '+project_id+';\n}\n';(project/'project.pbxproj').write_text(text)
scheme_dir=project/'xcshareddata/xcschemes';scheme_dir.mkdir(parents=True,exist_ok=True)
for name in ['LumaBasic','LumaHealth']:
 def buildable(n):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[n]}" BuildableName="{ "LumaSleep.app" if n in ["LumaBasic","LumaHealth"] else "LumaUITests.xctest" }" BlueprintName="{n}" ReferencedContainer="container:LumaSleep.xcodeproj"/>'
 test=f'<Testables><TestableReference skipped="NO">{buildable("LumaUITests")}</TestableReference></Testables>' if name=='LumaBasic' else '<Testables/>'
 xml=f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable(name)}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">{test}</TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(name)}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(name)}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>"""
 (scheme_dir/(name+'.xcscheme')).write_text(xml+'\n')
print(f'Generated LumaSleep.xcodeproj with {len(app_paths)} shared app/core sources and two app schemes.')
