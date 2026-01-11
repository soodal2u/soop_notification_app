package com.example.soop_notification_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import id.flutter.flutter_background_service.BackgroundService

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Check if service was running before reboot by checking SharedPreferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val wasServiceRunning = prefs.getBoolean("flutter.service_running", false)
            
            if (wasServiceRunning) {
                // Restart the background service
                val serviceIntent = Intent(context, BackgroundService::class.java)
                context.startForegroundService(serviceIntent)
            }
        }
    }
}
