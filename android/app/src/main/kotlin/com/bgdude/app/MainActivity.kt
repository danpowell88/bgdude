package com.bgdude.app

import com.bgdude.app.pump.PumpBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Single Flutter activity. Wires up the pump bridge (Pigeon host API + the pump-events
 * EventChannel) against the Flutter engine. The actual BLE work lives in [PumpService];
 * the bridge just relays commands to it and streams state back.
 */
class MainActivity : FlutterActivity() {

    private lateinit var pumpBridge: PumpBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        CrashLogger.install(applicationContext) // TASK-187: idempotent, process-wide
        pumpBridge = PumpBridge(applicationContext, flutterEngine)
        pumpBridge.attach()
    }

    override fun onDestroy() {
        if (this::pumpBridge.isInitialized) {
            pumpBridge.detach()
        }
        super.onDestroy()
    }
}
