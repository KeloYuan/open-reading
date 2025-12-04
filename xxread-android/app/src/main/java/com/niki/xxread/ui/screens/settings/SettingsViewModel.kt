package com.niki.xxread.ui.screens.settings

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    application: Application
) : AndroidViewModel(application) {
    
    private val settingsDataStore = SettingsDataStore(application)
    
    val settings: StateFlow<AppSettings> = settingsDataStore.settingsFlow
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = AppSettings()
        )
    
    fun updateDarkMode(enabled: Boolean) {
        viewModelScope.launch {
            settingsDataStore.updateDarkMode(enabled)
        }
    }
    
    fun updateDynamicColor(enabled: Boolean) {
        viewModelScope.launch {
            settingsDataStore.updateDynamicColor(enabled)
        }
    }
    
    fun updateEnableAnimations(enabled: Boolean) {
        viewModelScope.launch {
            settingsDataStore.updateEnableAnimations(enabled)
        }
    }
    
    fun updateFontSize(size: Float) {
        viewModelScope.launch {
            settingsDataStore.updateFontSize(size)
        }
    }
    
    fun updateLineHeight(height: Float) {
        viewModelScope.launch {
            settingsDataStore.updateLineHeight(height)
        }
    }
    
    fun updateEnablePageAnimation(enabled: Boolean) {
        viewModelScope.launch {
            settingsDataStore.updateEnablePageAnimation(enabled)
        }
    }
    
    fun updateEnableVolumeKeyTurn(enabled: Boolean) {
        viewModelScope.launch {
            settingsDataStore.updateEnableVolumeKeyTurn(enabled)
        }
    }
    
    fun updateKeepScreenOn(enabled: Boolean) {
        viewModelScope.launch {
            settingsDataStore.updateKeepScreenOn(enabled)
        }
    }
    
    fun updateEnableTts(enabled: Boolean) {
        viewModelScope.launch {
            settingsDataStore.updateEnableTts(enabled)
        }
    }
    
    fun updateTtsSpeed(speed: Float) {
        viewModelScope.launch {
            settingsDataStore.updateTtsSpeed(speed)
        }
    }
    
    fun updateTtsPitch(pitch: Float) {
        viewModelScope.launch {
            settingsDataStore.updateTtsPitch(pitch)
        }
    }
    
    fun updateEnableAutoSave(enabled: Boolean) {
        viewModelScope.launch {
            settingsDataStore.updateEnableAutoSave(enabled)
        }
    }
    
    fun updateAutoSaveInterval(interval: Int) {
        viewModelScope.launch {
            settingsDataStore.updateAutoSaveInterval(interval)
        }
    }
}
