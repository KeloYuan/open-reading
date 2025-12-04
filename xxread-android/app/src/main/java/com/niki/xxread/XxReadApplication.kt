package com.niki.xxread

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class XxReadApplication : Application() {
    
    override fun onCreate() {
        super.onCreate()
        // 初始化应用
    }
}
