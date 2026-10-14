import os
import sys

def patch(android_dir):
    # 1. إضافة تعطيل فحص AAR Metadata إلى gradle.properties
    props_path = os.path.join(android_dir, 'gradle.properties')
    prop_line = 'android.dependency.enforceCheckAarMetadata=false
'
    if os.path.exists(props_path):
        with open(props_path, 'r', encoding='utf-8') as f:
            lines = f.read()
        if prop_line not in lines:
            with open(props_path, 'a', encoding='utf-8') as f:
                f.write(prop_line)
            print('Added enforceCheckAarMetadata=false to gradle.properties')

    # 2. ضبط compileSdk إلى 35/36 في app/build.gradle.kts
    app_kts = os.path.join(android_dir, 'app', 'build.gradle.kts')
    if os.path.exists(app_kts):
        with open(app_kts, 'r', encoding='utf-8') as f:
            c = f.read()
        c = c.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 35')
        with open(app_kts, 'w', encoding='utf-8') as f:
            f.write(c)
        print('Adjusted app/build.gradle.kts compileSdk')

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else 'android'
    patch(target)
