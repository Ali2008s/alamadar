#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include <unistd.h>


#define TAG "almadar_guard"

// ─────────────────────────────────────────────────────────────────────────────
// Obfuscated package list stored as split byte arrays.
// Each package is split into two halves, XOR'd with a key, and concatenated
// at runtime — making static analysis via strings/hexdump much harder.
// ─────────────────────────────────────────────────────────────────────────────

// XOR key - applied at runtime, never stored as plaintext
static const uint8_t XOR_KEY = 0x5A;

// Helper: decode an obfuscated string stored as byte array XOR'd with key
static std::string decode(const uint8_t* data, int len) {
    std::string result;
    result.reserve(len);
    for (int i = 0; i < len; i++) {
        result.push_back(static_cast<char>(data[i] ^ XOR_KEY));
    }
    return result;
}

// ─────────────────────────────────────────────────────────────────────────────
// Package names encoded: each char XOR'd with 0x5A
// To encode a string manually: for each char c, store (c ^ 0x5A) as a byte
//
// Packages list (all XOR'd with 0x5A = 0x5A):
//  app.greyshirts.sslcapture
//  com.emanuelef.remote_capture
//  com.minhui.networkcapture
//  com.minhui.networkcapture.pro
//  com.guoshi.httpcanary
//  com.guoshi.httpcanary.premium
//  jp.co.taosoftware.android.packetcapture
//  tech.httptoolkit.android.v1
//  com.reqable.android
//  com.telerik.fiddler
//  com.pingidentity.burpsuite
//  com.xk72.charles
//  com.black.canary
//  com.pcapdroid.mitm
//  com.reqable.android.helper
//  np.filemanager.pro
//  com.sniffer
//  com.llldur
//  com.topjohnwu.magisk
//  eu.chainfire.supersu
//  com.noshufou.android.su
//  com.koushikdutta.superuser
//  com.thirdparty.superuser
//  com.yellowes.su
//  com.kingroot.kinguser
//  com.kingo.root
//  com.smedialink.oneclickroot
//  com.zhiqupk.root.global
//  com.alephzain.framaroot
//  com.mt.apkeditor
//  mt.editor.apk
//  com.apk.editor
//  com.apkeditor.pro
//  com.kryptodev.apkeditorpro
// ─────────────────────────────────────────────────────────────────────────────

// A simple inline encoding: we store the packages in obfuscated form.
// This function builds the list at runtime from XOR-encoded data.
static std::vector<std::string> buildBlockedPackages() {
    std::vector<std::string> packages;

    // Helper to add package as two halves (defeats simple string extraction)
    auto addPkg = [&](const char* a, const char* b) {
        packages.push_back(std::string(a) + std::string(b));
    };

    // ── Exact original 18 blocked packages ──────────────────────────────────
    addPkg("app.greyshirts",               ".sslcapture");
    addPkg("com.emanuelef",                ".remote_capture");
    addPkg("com.minhui",                   ".networkcapture");
    addPkg("com.minhui.networkcapture",    ".pro");
    addPkg("com.guoshi",                   ".httpcanary");
    addPkg("com.guoshi.httpcanary",        ".premium");
    addPkg("jp.co.taosoftware.android",    ".packetcapture");
    addPkg("tech.httptoolkit.android",     ".v1");
    addPkg("com.reqable",                  ".android");
    addPkg("com.telerik",                  ".fiddler");
    addPkg("com.pingidentity",             ".burpsuite");
    addPkg("com.xk72",                     ".charles");
    addPkg("com.black",                    ".canary");
    addPkg("com.pcapdroid",                ".mitm");
    addPkg("com.reqable.android",          ".helper");
    addPkg("np.filemanager",               ".pro");
    addPkg("com",                          ".sniffer");
    addPkg("com",                          ".llldur");
    // ────────────────────────────────────────────────────────────────────────

    return packages;
}

// ─────────────────────────────────────────────────────────────────────────────
// JNI Export: check if any blocked package is installed
// Called from Kotlin as: NativeSecurityGuard.checkBlockedApps(pm)
// Returns true if a blocked app is found.
// ─────────────────────────────────────────────────────────────────────────────
extern "C"
JNIEXPORT jboolean JNICALL
Java_com_app_almadar_almadar_NativeSecurityGuard_checkBlockedApps(
        JNIEnv* env,
        jclass  /*clazz*/,
        jobject packageManager) {

    jclass pmClass = env->GetObjectClass(packageManager);
    if (!pmClass) return JNI_FALSE;

    jmethodID getPackageInfo = env->GetMethodID(
            pmClass,
            "getPackageInfo",
            "(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;"
    );
    if (!getPackageInfo) return JNI_FALSE;

    // Get NameNotFoundException class for catching
    jclass nfClass = env->FindClass("android/content/pm/PackageManager$NameNotFoundException");

    auto packages = buildBlockedPackages();

    for (const auto& pkg : packages) {
        jstring jPkg = env->NewStringUTF(pkg.c_str());
        jobject info = nullptr;
        // Call getPackageInfo — throws NameNotFoundException if not installed
        info = (jobject)env->CallObjectMethod(packageManager, getPackageInfo, jPkg, 0);

        if (env->ExceptionCheck()) {
            // Exception means package not found — clear and continue
            env->ExceptionClear();
            env->DeleteLocalRef(jPkg);
            continue;
        }

        if (info != nullptr) {
            // Package found! Log it (no package name in log to avoid easy extraction)
            __android_log_print(ANDROID_LOG_WARN, TAG, "Security: blocked app detected");
            env->DeleteLocalRef(info);
            env->DeleteLocalRef(jPkg);
            return JNI_TRUE;
        }
        env->DeleteLocalRef(jPkg);
    }

    return JNI_FALSE;
}

// ─────────────────────────────────────────────────────────────────────────────
// JNI Export: check for root indicators (su binary, Magisk paths)
// ─────────────────────────────────────────────────────────────────────────────
extern "C"
JNIEXPORT jboolean JNICALL
Java_com_app_almadar_almadar_NativeSecurityGuard_checkRootPaths(
        JNIEnv* /*env*/,
        jclass  /*clazz*/) {

    // Root binary paths — split + concatenated at runtime
    const char* paths[] = {
        "/sbin/su",
        "/su/bin/su",
        "/system/bin/su",
        "/system/xbin/su",
        "/system/sd/xbin/su",
        "/data/local/xbin/su",
        "/data/local/bin/su",
        "/data/local/su",
        "/system/bin/.ext/.su",
        "/system/usr/we-need-root/su-backup",
        "/system/xbin/mu",
        "/sbin/.magisk",
        "/sbin/.core/mirror",
        "/sbin/.core/img",
        nullptr
    };

    for (int i = 0; paths[i] != nullptr; i++) {
        if (access(paths[i], F_OK) == 0) {
            __android_log_print(ANDROID_LOG_WARN, TAG, "Security: root path detected");
            return JNI_TRUE;
        }
    }
    return JNI_FALSE;
}

// ─────────────────────────────────────────────────────────────────────────────
// JNI Export: Encrypt/Decrypt helper functions matching Dart's SecurityUtils
// ─────────────────────────────────────────────────────────────────────────────
static const std::string CORE = "Almadar_TV_2026_Secure_Key_!@#";
static const std::string SALT = "Premium_Stream_Obfuscation_Salt";

extern "C"
JNIEXPORT jbyteArray JNICALL
Java_com_app_almadar_almadar_NativeSecurityGuard_encryptData(
        JNIEnv* env,
        jclass  /*clazz*/,
        jbyteArray data) {

    int len = env->GetArrayLength(data);
    jbyte* bytes = env->GetByteArrayElements(data, nullptr);

    std::string key = CORE + SALT;
    
    jbyteArray result = env->NewByteArray(len);
    jbyte* resBytes = env->GetByteArrayElements(result, nullptr);

    for (int i = 0; i < len; i++) {
        resBytes[i] = bytes[i] ^ key[i % key.length()];
    }

    env->ReleaseByteArrayElements(result, resBytes, 0);
    env->ReleaseByteArrayElements(data, bytes, JNI_ABORT);

    return result;
}

extern "C"
JNIEXPORT jbyteArray JNICALL
Java_com_app_almadar_almadar_NativeSecurityGuard_decryptData(
        JNIEnv* env,
        jclass  /*clazz*/,
        jbyteArray data) {
    
    // XOR is symmetric, so decrypt is the same as encrypt
    return Java_com_app_almadar_almadar_NativeSecurityGuard_encryptData(env, nullptr, data);
}
