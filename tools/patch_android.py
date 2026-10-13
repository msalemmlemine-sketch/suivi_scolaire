"""Post-`flutter create` patch of the generated android/ project.
 - sets the visible app name
 - if android/key.properties exists, signs the release build with it
Fails loudly when the generated template no longer matches, so a silent
debug-signed build is never mistaken for a signed one."""
import pathlib, re, sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "android")

manifest = root / "app/src/main/AndroidManifest.xml"
m = manifest.read_text(encoding="utf-8")
m = re.sub(r'android:label="[^"]*"', 'android:label="Suivi Scolaire"', m, count=1)
manifest.write_text(m, encoding="utf-8")

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


subprojects {
    afterEvaluate { project ->
        if (project.hasProperty('android')) {
            project.android {
                compileSdkVersion 36
            }
        }
    }
}
