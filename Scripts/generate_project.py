#!/usr/bin/env python3
"""Regenerates BridgeInspect.xcodeproj from the source tree.

Run after adding or removing Swift files:
    python3 Scripts/generate_project.py
"""
import os, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = "BridgeInspect"
UNIT = "BridgeInspectTests"
UI = "BridgeInspectUITests"
BUNDLE = "com.dylantzachar.bridgeinspect"
DEPLOY = "18.0"

def oid(seed):
    return uuid.uuid5(uuid.NAMESPACE_DNS, seed).hex[:24].upper()

def collect(folder):
    out = []
    base = os.path.join(ROOT, folder)
    if not os.path.isdir(base):
        return out
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames.sort()
        for fn in sorted(filenames):
            if fn.endswith(".swift"):
                out.append(os.path.relpath(os.path.join(dirpath, fn), ROOT))
    return out

app_src, unit_src, ui_src = collect(APP), collect(UNIT), collect(UI)

# Asset catalogs are compiled by the resources phase, not the sources phase.
ASSETS = os.path.join(APP, "Resources", "Assets.xcassets")
has_assets = os.path.isdir(os.path.join(ROOT, ASSETS))

build_files, file_refs, groups = [], [], []

def add_files(sources, tag):
    entries = []
    for rel in sources:
        name = os.path.basename(rel)
        fr, bf = oid(f"fr:{tag}:{rel}"), oid(f"bf:{tag}:{rel}")
        file_refs.append(f'\t\t{fr} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = "<group>"; }};')
        build_files.append(f'\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};')
        entries.append(f'\t\t\t\t{bf} /* {name} in Sources */,')
    return entries

def build_tree(sources):
    tree = {}
    for rel in sources:
        parts = rel.split(os.sep)
        node = tree
        for p in parts[:-1]:
            node = node.setdefault(p, {})
        node.setdefault("__files__", []).append((parts[-1], rel))
    return tree

def emit_group(node, path, tag):
    gid = oid(f"g:{tag}:{path}")
    children = []
    if node.get("__assets__"):
        children.append(f'\t\t\t\t{oid("fr:assets")} /* Assets.xcassets */,')
    for key in sorted(k for k in node if k not in ("__files__", "__assets__")):
        child = path + "/" + key
        children.append(f'\t\t\t\t{oid(f"g:{tag}:{child}")} /* {key} */,')
        emit_group(node[key], child, tag)
    for name, rel in node.get("__files__", []):
        children.append(f'\t\t\t\t{oid(f"fr:{tag}:{rel}")} /* {name} */,')
    label = os.path.basename(path)
    groups.append(f'''\t\t{gid} /* {label} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(children)}
\t\t\t);
\t\t\tpath = "{label}";
\t\t\tsourceTree = "<group>";
\t\t}};''')
    return gid

ASSET_FR = oid("fr:assets")
ASSET_BF = oid("bf:assets")
asset_res_entries = ""
if has_assets:
    file_refs.append(f'\t\t{ASSET_FR} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = "Assets.xcassets"; sourceTree = "<group>"; }};')
    build_files.append(f'\t\t{ASSET_BF} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ASSET_FR} /* Assets.xcassets */; }};')
    asset_res_entries = f'\t\t\t\t{ASSET_BF} /* Assets.xcassets in Resources */,'

app_entries = add_files(app_src, "app")
unit_entries = add_files(unit_src, "unit")
ui_entries = add_files(ui_src, "ui")

app_tree = build_tree(app_src)[APP]
if has_assets:
    # Surface the catalog under its real folder so Xcode resolves the path.
    app_tree.setdefault("Resources", {})["__assets__"] = True
app_group = emit_group(app_tree, APP, "app")
unit_group = emit_group(build_tree(unit_src)[UNIT], UNIT, "unit") if unit_src else None
ui_group = emit_group(build_tree(ui_src)[UI], UI, "ui") if ui_src else None

T_APP, T_UNIT, T_UI = oid("t:app"), oid("t:unit"), oid("t:ui")
P_APP, P_UNIT, P_UI = oid("p:app"), oid("p:unit"), oid("p:ui")
PROJECT, ROOTG, PRODG = oid("project"), oid("rootgroup"), oid("productsgroup")

def phases(tag):
    return oid(f"src:{tag}"), oid(f"frm:{tag}"), oid(f"res:{tag}")

S_APP, F_APP, R_APP = phases("app")
S_UNIT, F_UNIT, R_UNIT = phases("unit")
S_UI, F_UI, R_UI = phases("ui")

def phase_block(pid, isa, entries=""):
    return f'''\t\t{pid} = {{
\t\t\tisa = {isa};
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{entries}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};'''

targets = [(T_APP, APP, P_APP, f"{APP}.app", "com.apple.product-type.application", (S_APP, F_APP, R_APP), [])]
if unit_src:
    targets.append((T_UNIT, UNIT, P_UNIT, f"{UNIT}.xctest", "com.apple.product-type.bundle.unit-test", (S_UNIT, F_UNIT, R_UNIT), [oid("dep:unit")]))
if ui_src:
    targets.append((T_UI, UI, P_UI, f"{UI}.xctest", "com.apple.product-type.bundle.ui-testing", (S_UI, F_UI, R_UI), [oid("dep:ui")]))

target_blocks, dep_blocks, proxy_blocks = [], [], []
for tid, name, pid, prodname, ptype, (sp, fp, rp), deps in targets:
    dep_list = "".join(f'\n\t\t\t\t{d},' for d in deps)
    target_blocks.append(f'''\t\t{tid} /* {name} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {oid(f"cl:{name}")};
\t\t\tbuildPhases = (
\t\t\t\t{sp},
\t\t\t\t{fp},
\t\t\t\t{rp},
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = ({dep_list}
\t\t\t);
\t\t\tname = "{name}";
\t\t\tproductName = "{name}";
\t\t\tproductReference = {pid} /* {prodname} */;
\t\t\tproductType = "{ptype}";
\t\t}};''')
    for d in deps:
        proxy = oid(f"proxy:{d}")
        dep_blocks.append(f'''\t\t{d} = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {T_APP} /* {APP} */;
\t\t\ttargetProxy = {proxy};
\t\t}};''')
        proxy_blocks.append(f'''\t\t{proxy} = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {PROJECT} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {T_APP};
\t\t\tremoteInfo = "{APP}";
\t\t}};''')

BASE_DEBUG = f'''\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOY};
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";'''

BASE_RELEASE = f'''\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOY};
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;'''

COMMON = f'''\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_STRICT_CONCURRENCY = complete;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1";'''

APP_SETTINGS = f'''{COMMON}
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tINFOPLIST_KEY_NSCameraUsageDescription = "Take photos and videos of walls during inspection.";
\t\t\t\tINFOPLIST_KEY_NSMicrophoneUsageDescription = "Record audio with inspection videos.";
\t\t\t\tINFOPLIST_KEY_NSPhotoLibraryUsageDescription = "Attach existing photos to a wall.";
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOY};
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE}";'''

UNIT_SETTINGS = f'''{COMMON}
\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOY};
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE}.tests";
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/{APP}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{APP}";'''

UI_SETTINGS = f'''{COMMON}
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {DEPLOY};
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "{BUNDLE}.uitests";
\t\t\t\tTEST_TARGET_NAME = "{APP}";'''

cfg_blocks, cfglist_blocks = [], []
def add_configs(name, settings):
    d, r = oid(f"cfg:{name}:debug"), oid(f"cfg:{name}:release")
    cfg_blocks.append(f'''\t\t{d} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{settings}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{r} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{settings}
\t\t\t}};
\t\t\tname = Release;
\t\t}};''')
    cfglist_blocks.append(f'''\t\t{oid(f"cl:{name}")} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{d} /* Debug */,
\t\t\t\t{r} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};''')

add_configs("__project_debug__", BASE_DEBUG)
PD, PR = oid("cfg:__project_debug__:debug"), oid("cfg:__project_debug__:release")
cfg_blocks[-1] = cfg_blocks[-1].replace(BASE_DEBUG, BASE_DEBUG, 1)
cfg_blocks[-1] = f'''\t\t{PD} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{BASE_DEBUG}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{PR} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{BASE_RELEASE}
\t\t\t}};
\t\t\tname = Release;
\t\t}};'''
cfglist_blocks[-1] = f'''\t\t{oid("cl:__project__")} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{PD} /* Debug */,
\t\t\t\t{PR} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};'''

add_configs(APP, APP_SETTINGS)
if unit_src: add_configs(UNIT, UNIT_SETTINGS)
if ui_src: add_configs(UI, UI_SETTINGS)

prod_children = [f'\t\t\t\t{P_APP} /* {APP}.app */,']
prod_refs = [f'\t\t{P_APP} /* {APP}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "{APP}.app"; sourceTree = BUILT_PRODUCTS_DIR; }};']
root_children = [f'\t\t\t\t{app_group} /* {APP} */,']
if unit_src:
    prod_children.append(f'\t\t\t\t{P_UNIT} /* {UNIT}.xctest */,')
    prod_refs.append(f'\t\t{P_UNIT} /* {UNIT}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = "{UNIT}.xctest"; sourceTree = BUILT_PRODUCTS_DIR; }};')
    root_children.append(f'\t\t\t\t{unit_group} /* {UNIT} */,')
if ui_src:
    prod_children.append(f'\t\t\t\t{P_UI} /* {UI}.xctest */,')
    prod_refs.append(f'\t\t{P_UI} /* {UI}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = "{UI}.xctest"; sourceTree = BUILT_PRODUCTS_DIR; }};')
    root_children.append(f'\t\t\t\t{ui_group} /* {UI} */,')
root_children.append(f'\t\t\t\t{PRODG} /* Products */,')

all_phases = [phase_block(S_APP, "PBXSourcesBuildPhase", chr(10).join(app_entries)),
              phase_block(F_APP, "PBXFrameworksBuildPhase"),
              phase_block(R_APP, "PBXResourcesBuildPhase", asset_res_entries)]
if unit_src:
    all_phases += [phase_block(S_UNIT, "PBXSourcesBuildPhase", chr(10).join(unit_entries)),
                   phase_block(F_UNIT, "PBXFrameworksBuildPhase"),
                   phase_block(R_UNIT, "PBXResourcesBuildPhase")]
if ui_src:
    all_phases += [phase_block(S_UI, "PBXSourcesBuildPhase", chr(10).join(ui_entries)),
                   phase_block(F_UI, "PBXFrameworksBuildPhase"),
                   phase_block(R_UI, "PBXResourcesBuildPhase")]

src_p = [p for p in all_phases if "PBXSourcesBuildPhase" in p]
frm_p = [p for p in all_phases if "PBXFrameworksBuildPhase" in p]
res_p = [p for p in all_phases if "PBXResourcesBuildPhase" in p]

target_list = "".join(f'\n\t\t\t\t{t[0]} /* {t[1]} */,' for t in targets)

pbx = f'''// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
{chr(10).join(proxy_blocks)}
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
{chr(10).join(prod_refs)}
{chr(10).join(file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
{chr(10).join(frm_p)}
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{ROOTG} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(root_children)}
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{PRODG} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(prod_children)}
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
{chr(10).join(groups)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
{chr(10).join(target_blocks)}
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{PROJECT} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 2660;
\t\t\t\tLastUpgradeCheck = 2660;
\t\t\t}};
\t\t\tbuildConfigurationList = {oid("cl:__project__")};
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {ROOTG};
\t\t\tproductRefGroup = {PRODG} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = ({target_list}
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{chr(10).join(res_p)}
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{chr(10).join(src_p)}
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
{chr(10).join(dep_blocks)}
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
{chr(10).join(cfg_blocks)}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{chr(10).join(cfglist_blocks)}
/* End XCConfigurationList section */
\t}};
\trootObject = {PROJECT} /* Project object */;
}}
'''

projdir = os.path.join(ROOT, APP + ".xcodeproj")
os.makedirs(projdir, exist_ok=True)
with open(os.path.join(projdir, "project.pbxproj"), "w") as f:
    f.write(pbx)

testables = ""
for tid, name in [(T_UNIT, UNIT)] if unit_src else []:
    testables += f'''
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tid}"
               BuildableName = "{name}.xctest"
               BlueprintName = "{name}"
               ReferencedContainer = "container:{APP}.xcodeproj">
            </BuildableReference>
         </TestableReference>'''
for tid, name in [(T_UI, UI)] if ui_src else []:
    testables += f'''
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tid}"
               BuildableName = "{name}.xctest"
               BlueprintName = "{name}"
               ReferencedContainer = "container:{APP}.xcodeproj">
            </BuildableReference>
         </TestableReference>'''

schemedir = os.path.join(projdir, "xcshareddata", "xcschemes")
os.makedirs(schemedir, exist_ok=True)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2660" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{T_APP}"
               BuildableName = "{APP}.app"
               BlueprintName = "{APP}"
               ReferencedContainer = "container:{APP}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>{testables}
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{T_APP}"
            BuildableName = "{APP}.app"
            BlueprintName = "{APP}"
            ReferencedContainer = "container:{APP}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{T_APP}"
            BuildableName = "{APP}.app"
            BlueprintName = "{APP}"
            ReferencedContainer = "container:{APP}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
'''
with open(os.path.join(schemedir, APP + ".xcscheme"), "w") as f:
    f.write(scheme)

print(f"app={len(app_src)} unit={len(unit_src)} ui={len(ui_src)} sources")
