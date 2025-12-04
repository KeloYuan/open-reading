package com.niki.xxread.ui.screens.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import java.io.IOException

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "settings")

class SettingsDataStore(private val context: Context) {
    
    companion object {
        // 外观设置
        val DARK_MODE = booleanPreferencesKey("dark_mode")
        val DYNAMIC_COLOR = booleanPreferencesKey("dynamic_color")
        val ENABLE_ANIMATIONS = booleanPreferencesKey("enable_animations")
        
        // 阅读设置
        val FONT_SIZE = floatPreferencesKey("font_size")
        val LINE_HEIGHT = floatPreferencesKey("line_height")
        val ENABLE_PAGE_ANIMATION = booleanPreferencesKey("enable_page_animation")
        val ENABLE_VOLUME_KEY_TURN = booleanPreferencesKey("enable_volume_key_turn")
        val KEEP_SCREEN_ON = booleanPreferencesKey("keep_screen_on")
        
        // TTS设置
        val ENABLE_TTS = booleanPreferencesKey("enable_tts")
        val TTS_SPEED = floatPreferencesKey("tts_speed")
        val TTS_PITCH = floatPreferencesKey("tts_pitch")
        
        // 其他设置
        val ENABLE_AUTO_SAVE = booleanPreferencesKey("enable_auto_save")
        val AUTO_SAVE_INTERVAL = intPreferencesKey("auto_save_interval")
    }
    
    val settingsFlow: Flow<AppSettings> = context.dataStore.data
        .catch { exception ->
            if (exception is IOException) {
                emit(emptyPreferences())
            } else {
                throw exception
            }
        }
        .map { preferences ->
            AppSettings(
                darkMode = preferences[DARK_MODE] ?: false,
                dynamicColor = preferences[DYNAMIC_COLOR] ?: true,
                enableAnimations = preferences[ENABLE_ANIMATIONS] ?: true,
                fontSize = preferences[FONT_SIZE] ?: 18f,
                lineHeight = preferences[LINE_HEIGHT] ?: 1.5f,
                enablePageAnimation = preferences[ENABLE_PAGE_ANIMATION] ?: true,
                enableVolumeKeyTurn = preferences[ENABLE_VOLUME_KEY_TURN] ?: true,
                keepScreenOn = preferences[KEEP_SCREEN_ON] ?: false,
                enableTts = preferences[ENABLE_TTS] ?: true,
                ttsSpeed = preferences[TTS_SPEED] ?: 1.0f,
                ttsPitch = preferences[TTS_PITCH] ?: 1.0f,
                enableAutoSave = preferences[ENABLE_AUTO_SAVE] ?: true,
                autoSaveInterval = preferences[AUTO_SAVE_INTERVAL] ?: 30
            )
        }
    
    suspend fun updateDarkMode(enabled: Boolean) {
        context.dataStore.edit { it[DARK_MODE] = enabled }
    }
    
    suspend fun updateDynamicColor(enabled: Boolean) {
        context.dataStore.edit { it[DYNAMIC_COLOR] = enabled }
    }
    
    suspend fun updateEnableAnimations(enabled: Boolean) {
        context.dataStore.edit { it[ENABLE_ANIMATIONS] = enabled }
    }
    
    suspend fun updateFontSize(size: Float) {
        context.dataStore.edit { it[FONT_SIZE] = size }
    }
    
    suspend fun updateLineHeight(height: Float) {
        context.dataStore.edit { it[LINE_HEIGHT] = height }
    }
    
    suspend fun updateEnablePageAnimation(enabled: Boolean) {
        context.dataStore.edit { it[ENABLE_PAGE_ANIMATION] = enabled }
    }
    
    suspend fun updateEnableVolumeKeyTurn(enabled: Boolean) {
        context.dataStore.edit { it[ENABLE_VOLUME_KEY_TURN] = enabled }
    }
    
    suspend fun updateKeepScreenOn(enabled: Boolean) {
        context.dataStore.edit { it[KEEP_SCREEN_ON] = enabled }
    }
    
    suspend fun updateEnableTts(enabled: Boolean) {
        context.dataStore.edit { it[ENABLE_TTS] = enabled }
    }
    
    suspend fun updateTtsSpeed(speed: Float) {
        context.dataStore.edit { it[TTS_SPEED] = speed }
    }
    
    suspend fun updateTtsPitch(pitch: Float) {
        context.dataStore.edit { it[TTS_PITCH] = pitch }
    }
    
    suspend fun updateEnableAutoSave(enabled: Boolean) {
        context.dataStore.edit { it[ENABLE_AUTO_SAVE] = enabled }
    }
    
    suspend fun updateAutoSaveInterval(interval: Int) {
        context.dataStore.edit { it[AUTO_SAVE_INTERVAL] = interval }
    }
}

data class AppSettings(
    val darkMode: Boolean = false,
    val dynamicColor: Boolean = true,
    val enableAnimations: Boolean = true,
    val fontSize: Float = 18f,
    val lineHeight: Float = 1.5f,
    val enablePageAnimation: Boolean = true,
    val enableVolumeKeyTurn: Boolean = true,
    val keepScreenOn: Boolean = false,
    val enableTts: Boolean = true,
    val ttsSpeed: Float = 1.0f,
    val ttsPitch: Float = 1.0f,
    val enableAutoSave: Boolean = true,
    val autoSaveInterval: Int = 30
)
