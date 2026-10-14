"""Post-`flutter create` patch of the generated android/ project.
 - sets the visible app name
 - installs the launcher icons from tools/icons/
 - if android/key.properties exists, signs the release build with it
Fails loudly when the generated template no longer matches, so a silent
debug-signed build is never mistaken for a signed one."""
import pathlib, re, shutil, sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "android")

manifest = root / "app/src/main/AndroidManifest.xml"
m = manifest.read_text(encoding="utf-8")
m = re.sub(r'android:label="[^"]*"', 'android:label="Suivi Scolaire"', m, count=1)
manifest.write_text(m, encoding="utf-8")

icons = pathlib.Path(__file__).resolve().parent / "icons"
for src in sorted(icons.glob("mipmap-*/ic_launcher.png")):
    dest = root / "app/src/main/res" / src.parent.name / "ic_launcher.png"
    if not dest.parent.exists():
        sys.exit(f"ERROR: {dest.parent} missing; update tools/patch_android.py")
    shutil.copyfile(src, dest)
print("launcher icons installed")

if not (root / "key.properties").exists():
    print("no key.properties -> leaving debug signing (unsigned-by-owner build)")
    sys.exit(0)

gradle = root / "app/build.gradle.kts"
g = gradle.read_text(encoding="utf-8")
if 'signingConfigs.getByName("debug")' not in g or "buildTypes {" not in g:
    sys.exit("ERROR: build.gradle.kts template changed; update tools/patch_android.py")

block = '''    signingConfigs {
        create("release") {
            val props = java.util.Properties()
            props.load(java.io.FileInputStream(rootProject.file("key.properties")))
            keyAlias = props["keyAlias"] as String
            keyPassword = props["keyPassword"] as String
            storeFile = file(props["storeFile"] as String)
            storePassword = props["storePassword"] as String
        }
    }

'''
g = g.replace("    buildTypes {", block + "    buildTypes {", 1)
g = g.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")', 1)
gradle.write_text(g, encoding="utf-8")
print("release signing configured")
