package com.example.xxread

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.graphics.Color
import android.view.View
import android.view.Window
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.ViewCompat

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 设置沉浸式"小白条"效果
        setupImmersiveMode()
    }
    
    override fun onResume() {
        super.onResume()
        // 在Resume时重新应用沉浸式设置，防止被其他应用影响
        setupImmersiveMode()
    }
    
    private fun setupImmersiveMode() {
        val window: Window = window
        
        // 强制设置窗口标志，确保沉浸式效果
        window.setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
        
        // 允许内容绘制到系统栏区域
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // 设置导航栏和状态栏为透明
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        
        // 使用更强制的系统UI隐藏标志
        val flags = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY)
        
        window.decorView.systemUiVisibility = flags
        
        // 设置导航栏分割线透明
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            window.navigationBarDividerColor = Color.TRANSPARENT
        }
        
        // 强制设置导航栏样式（Android 11+）
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        }
        
        // 确保软键盘模式不影响沉浸式
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
    }
}
