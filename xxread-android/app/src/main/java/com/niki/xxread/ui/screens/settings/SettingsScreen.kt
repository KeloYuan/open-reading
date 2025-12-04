package com.niki.xxread.ui.screens.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val settings by viewModel.settings.collectAsState()
    
    Scaffold(
        topBar = {
            LargeTopAppBar(
                title = {
                    Text(
                        "设置",
                        fontWeight = FontWeight.Bold
                    )
                }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 外观设置
            item {
                SettingsSection(title = "外观") {
                    SettingsSwitchItem(
                        icon = Icons.Outlined.DarkMode,
                        title = "深色模式",
                        subtitle = "启用深色主题",
                        checked = settings.darkMode,
                        onCheckedChange = { viewModel.updateDarkMode(it) }
                    )
                    
                    SettingsSwitchItem(
                        icon = Icons.Outlined.Palette,
                        title = "动态颜色",
                        subtitle = "使用系统动态配色（Android 12+）",
                        checked = settings.dynamicColor,
                        onCheckedChange = { viewModel.updateDynamicColor(it) }
                    )
                    
                    SettingsSwitchItem(
                        icon = Icons.Outlined.Animation,
                        title = "动画效果",
                        subtitle = "启用界面动画",
                        checked = settings.enableAnimations,
                        onCheckedChange = { viewModel.updateEnableAnimations(it) }
                    )
                }
            }
            
            // 阅读设置
            item {
                SettingsSection(title = "阅读") {
                    SettingsSliderItem(
                        icon = Icons.Outlined.FormatSize,
                        title = "字体大小",
                        value = settings.fontSize,
                        valueRange = 12f..32f,
                        valueText = "${settings.fontSize.toInt()} sp",
                        onValueChange = { viewModel.updateFontSize(it) }
                    )
                    
                    SettingsSliderItem(
                        icon = Icons.Outlined.FormatLineSpacing,
                        title = "行高",
                        value = settings.lineHeight,
                        valueRange = 1.0f..2.5f,
                        valueText = "%.1f".format(settings.lineHeight),
                        onValueChange = { viewModel.updateLineHeight(it) }
                    )
                    
                    SettingsSwitchItem(
                        icon = Icons.Outlined.SwipeRight,
                        title = "翻页动画",
                        subtitle = "启用翻页过渡动画",
                        checked = settings.enablePageAnimation,
                        onCheckedChange = { viewModel.updateEnablePageAnimation(it) }
                    )
                    
                    SettingsSwitchItem(
                        icon = Icons.Outlined.VolumeUp,
                        title = "音量键翻页",
                        subtitle = "使用音量键控制翻页",
                        checked = settings.enableVolumeKeyTurn,
                        onCheckedChange = { viewModel.updateEnableVolumeKeyTurn(it) }
                    )
                    
                    SettingsSwitchItem(
                        icon = Icons.Outlined.LightMode,
                        title = "屏幕常亮",
                        subtitle = "阅读时保持屏幕开启",
                        checked = settings.keepScreenOn,
                        onCheckedChange = { viewModel.updateKeepScreenOn(it) }
                    )
                }
            }
            
            // TTS设置
            item {
                SettingsSection(title = "朗读") {
                    SettingsSwitchItem(
                        icon = Icons.Outlined.RecordVoiceOver,
                        title = "TTS 朗读",
                        subtitle = "启用文字转语音功能",
                        checked = settings.enableTts,
                        onCheckedChange = { viewModel.updateEnableTts(it) }
                    )
                    
                    if (settings.enableTts) {
                        SettingsSliderItem(
                            icon = Icons.Outlined.Speed,
                            title = "朗读速度",
                            value = settings.ttsSpeed,
                            valueRange = 0.5f..2.0f,
                            valueText = "%.1fx".format(settings.ttsSpeed),
                            onValueChange = { viewModel.updateTtsSpeed(it) }
                        )
                        
                        SettingsSliderItem(
                            icon = Icons.Outlined.GraphicEq,
                            title = "语调",
                            value = settings.ttsPitch,
                            valueRange = 0.5f..2.0f,
                            valueText = "%.1f".format(settings.ttsPitch),
                            onValueChange = { viewModel.updateTtsPitch(it) }
                        )
                    }
                }
            }
            
            // 其他设置
            item {
                SettingsSection(title = "其他") {
                    SettingsSwitchItem(
                        icon = Icons.Outlined.Save,
                        title = "自动保存",
                        subtitle = "自动保存阅读进度",
                        checked = settings.enableAutoSave,
                        onCheckedChange = { viewModel.updateEnableAutoSave(it) }
                    )
                }
            }
            
            // 关于
            item {
                SettingsSection(title = "关于") {
                    SettingsClickableItem(
                        icon = Icons.Outlined.Info,
                        title = "版本",
                        subtitle = "1.0.0",
                        onClick = { }
                    )
                    
                    SettingsClickableItem(
                        icon = Icons.Outlined.Code,
                        title = "开源许可",
                        onClick = { }
                    )
                }
            }
            
            item {
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(12.dp))
            content()
        }
    }
}

@Composable
private fun SettingsSwitchItem(
    icon: ImageVector,
    title: String,
    subtitle: String? = null,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange
        )
    }
}

@Composable
private fun SettingsSliderItem(
    icon: ImageVector,
    title: String,
    value: Float,
    valueRange: ClosedFloatingPointRange<Float>,
    valueText: String,
    onValueChange: (Float) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.width(16.dp))
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f)
            )
            Text(
                text = valueText,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }
        Slider(
            value = value,
            onValueChange = onValueChange,
            valueRange = valueRange,
            modifier = Modifier.padding(start = 40.dp)
        )
    }
}

@Composable
private fun SettingsClickableItem(
    icon: ImageVector,
    title: String,
    subtitle: String? = null,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0f)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.bodyLarge
                )
                if (subtitle != null) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
