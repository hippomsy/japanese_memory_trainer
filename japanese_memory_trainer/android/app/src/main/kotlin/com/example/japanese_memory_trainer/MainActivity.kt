package com.example.japanese_memory_trainer

import io.flutter.embedding.android.FlutterActivity
import android.view.WindowManager

// 2026-10-04 기기 내 번역(ML Kit) 채널은 인터넷 뉴스를 없애면서 함께 제거했다.
class MainActivity : FlutterActivity() {
    override fun onResume() {
        super.onResume()
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun onPause() {
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onPause()
    }
}
