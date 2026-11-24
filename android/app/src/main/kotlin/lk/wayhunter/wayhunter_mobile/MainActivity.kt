package lk.wayhunter.wayhunter_mobile

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wayhunter/maps_smoke")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isConfigured" -> result.success(hasMapsApiKey())
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION") // The int flags overload also works on Android versions below API 33.
    private fun hasMapsApiKey(): Boolean {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        return !info.metaData?.getString("com.google.android.geo.API_KEY").isNullOrBlank()
    }
}
