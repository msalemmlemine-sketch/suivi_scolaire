import os
import sys

def patch_android(android_dir):
    # 1. ترقيع android/build.gradle.kts أو settings/app
    app_gradle_kts = os.path.join(android_dir, 'app', 'build.gradle.kts')
    if os.path.exists(app_gradle_kts):
        with open(app_gradle_kts, 'r', encoding='utf-8') as f:
            content = f.read()
        # رفع compileSdk إلى 36
        content = content.replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
        content = content.replace('compileSdk = 34', 'compileSdk = 36')
        content = content.replace('compileSdk = 35', 'compileSdk = 36')
        with open(app_gradle_kts, 'w', encoding='utf-8') as f:
            f.write(content)
        print('Patched app/build.gradle.kts compileSdk to 36')

    # 2. ترقيع root build.gradle.kts لدعم compileSdk=36 في المكتبات الفرعية مثل file_picker
    root_gradle_kts = os.path.join(android_dir, 'build.gradle.kts')
    if os.path.exists(root_gradle_kts):
        with open(root_gradle_kts, 'r', encoding='utf-8') as f:
            content = f.read()
        subproject_hook = """
subprojects {
    afterEvaluate {
        val project = this
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt is com.android.build.gradle.BaseExtension) {
                androidExt.compileSdkVersion(36)
            }
        }
    }
}
"""
        if "subprojects {" not in content:
            content += "\n" + subproject_hook
            with open(root_gradle_kts, 'w', encoding='utf-8') as f:
                f.write(content)
            print('Patched root build.gradle.kts for subprojects')

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else 'android'
    patch_android(target)
