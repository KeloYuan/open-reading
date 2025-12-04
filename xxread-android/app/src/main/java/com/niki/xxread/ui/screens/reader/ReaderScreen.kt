package com.niki.xxread.ui.screens.reader

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.niki.xxread.data.model.Chapter
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderScreen(
    bookId: Long,
    viewModel: ReaderViewModel = hiltViewModel(),
    onBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val scope = rememberCoroutineScope()
    
    var showChapterDrawer by remember { mutableStateOf(false) }
    var showSettingsSheet by remember { mutableStateOf(false) }
    
    // 页面状态
    val pagerState = rememberPagerState(
        initialPage = uiState.currentPage,
        pageCount = { uiState.totalPages.coerceAtLeast(1) }
    )
    
    // 同步页面变化
    LaunchedEffect(pagerState.currentPage) {
        if (pagerState.currentPage != uiState.currentPage) {
            viewModel.goToPage(pagerState.currentPage)
        }
    }
    
    // 当 currentPage 从外部改变时同步到 pager
    LaunchedEffect(uiState.currentPage) {
        if (pagerState.currentPage != uiState.currentPage) {
            pagerState.scrollToPage(uiState.currentPage)
        }
    }
    
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surface)
    ) {
        if (uiState.isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center)
            )
        } else {
            // 阅读内容区域
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .fillMaxSize()
                    .pointerInput(Unit) {
                        detectTapGestures(
                            onTap = { offset ->
                                val screenWidth = size.width
                                when {
                                    offset.x < screenWidth * 0.3f -> {
                                        // 左侧点击 - 上一页
                                        scope.launch {
                                            if (pagerState.currentPage > 0) {
                                                pagerState.animateScrollToPage(pagerState.currentPage - 1)
                                            }
                                        }
                                    }
                                    offset.x > screenWidth * 0.7f -> {
                                        // 右侧点击 - 下一页
                                        scope.launch {
                                            if (pagerState.currentPage < uiState.totalPages - 1) {
                                                pagerState.animateScrollToPage(pagerState.currentPage + 1)
                                            }
                                        }
                                    }
                                    else -> {
                                        // 中间点击 - 显示/隐藏菜单
                                        viewModel.toggleOverlay()
                                    }
                                }
                            }
                        )
                    }
            ) { page ->
                ReaderPageContent(
                    pageNumber = page,
                    book = uiState.book,
                    chapter = uiState.currentChapter
                )
            }
            
            // 顶部覆盖层
            AnimatedVisibility(
                visible = uiState.showOverlay,
                enter = fadeIn() + slideInVertically(),
                exit = fadeOut() + slideOutVertically()
            ) {
                ReaderTopBar(
                    title = uiState.book?.title ?: "",
                    onBack = onBack,
                    onShowChapters = { showChapterDrawer = true }
                )
            }
            
            // 底部覆盖层
            AnimatedVisibility(
                visible = uiState.showOverlay,
                modifier = Modifier.align(Alignment.BottomCenter),
                enter = fadeIn() + slideInVertically(initialOffsetY = { it }),
                exit = fadeOut() + slideOutVertically(targetOffsetY = { it })
            ) {
                ReaderBottomBar(
                    currentPage = uiState.currentPage,
                    totalPages = uiState.totalPages,
                    isBookmarked = uiState.isCurrentPageBookmarked,
                    onPageChange = { page ->
                        scope.launch {
                            pagerState.scrollToPage(page)
                        }
                    },
                    onToggleBookmark = { viewModel.toggleBookmark() },
                    onShowSettings = { showSettingsSheet = true }
                )
            }
            
            // 页码指示器（始终显示）
            if (!uiState.showOverlay) {
                Text(
                    text = "${uiState.currentPage + 1} / ${uiState.totalPages}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 16.dp)
                )
            }
        }
    }
    
    // 章节抽屉
    if (showChapterDrawer) {
        ModalBottomSheet(
            onDismissRequest = { showChapterDrawer = false }
        ) {
            ChapterList(
                chapters = uiState.chapters,
                currentChapter = uiState.currentChapter,
                onChapterClick = { chapter ->
                    viewModel.goToChapter(chapter)
                    showChapterDrawer = false
                }
            )
        }
    }
    
    // 设置底部弹窗
    if (showSettingsSheet) {
        ModalBottomSheet(
            onDismissRequest = { showSettingsSheet = false }
        ) {
            ReaderSettingsSheet()
        }
    }
}

@Composable
private fun ReaderPageContent(
    pageNumber: Int,
    book: com.niki.xxread.data.model.Book?,
    chapter: Chapter?
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 24.dp, vertical = 48.dp)
    ) {
        // 章节标题
        chapter?.let {
            Text(
                text = it.title,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(modifier = Modifier.height(16.dp))
        }
        
        // 页面内容（这里是占位符，实际需要解析书籍内容）
        Box(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth(),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "第 ${pageNumber + 1} 页\n\n" +
                        "《${book?.title ?: ""}》\n\n" +
                        "这里将显示书籍内容...\n\n" +
                        "支持 EPUB、PDF、TXT 等格式",
                style = MaterialTheme.typography.bodyLarge.copy(
                    lineHeight = 28.sp
                ),
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReaderTopBar(
    title: String,
    onBack: () -> Unit,
    onShowChapters: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
        shadowElevation = 4.dp
    ) {
        TopAppBar(
            title = {
                Text(
                    text = title,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, "返回")
                }
            },
            actions = {
                IconButton(onClick = onShowChapters) {
                    Icon(Icons.Outlined.List, "目录")
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Transparent
            )
        )
    }
}

@Composable
private fun ReaderBottomBar(
    currentPage: Int,
    totalPages: Int,
    isBookmarked: Boolean,
    onPageChange: (Int) -> Unit,
    onToggleBookmark: () -> Unit,
    onShowSettings: () -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f),
        shadowElevation = 4.dp
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            // 进度条
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${currentPage + 1}",
                    style = MaterialTheme.typography.bodySmall
                )
                Slider(
                    value = currentPage.toFloat(),
                    onValueChange = { onPageChange(it.toInt()) },
                    valueRange = 0f..(totalPages - 1).coerceAtLeast(1).toFloat(),
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 8.dp)
                )
                Text(
                    text = "$totalPages",
                    style = MaterialTheme.typography.bodySmall
                )
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            // 工具栏
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                // 目录
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { }
                ) {
                    Icon(
                        imageVector = Icons.Outlined.List,
                        contentDescription = "目录"
                    )
                    Text(
                        text = "目录",
                        style = MaterialTheme.typography.labelSmall
                    )
                }
                
                // 书签
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = onToggleBookmark
                    )
                ) {
                    Icon(
                        imageVector = if (isBookmarked) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                        contentDescription = "书签",
                        tint = if (isBookmarked) MaterialTheme.colorScheme.primary else LocalContentColor.current
                    )
                    Text(
                        text = "书签",
                        style = MaterialTheme.typography.labelSmall
                    )
                }
                
                // 设置
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = onShowSettings
                    )
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Settings,
                        contentDescription = "设置"
                    )
                    Text(
                        text = "设置",
                        style = MaterialTheme.typography.labelSmall
                    )
                }
                
                // 朗读
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) { }
                ) {
                    Icon(
                        imageVector = Icons.Outlined.VolumeUp,
                        contentDescription = "朗读"
                    )
                    Text(
                        text = "朗读",
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }
        }
    }
}

@Composable
private fun ChapterList(
    chapters: List<Chapter>,
    currentChapter: Chapter?,
    onChapterClick: (Chapter) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 32.dp)
    ) {
        Text(
            text = "目录",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)
        )
        
        if (chapters.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "暂无章节信息",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 400.dp)
            ) {
                items(chapters) { chapter ->
                    val isSelected = chapter.id == currentChapter?.id
                    
                    ListItem(
                        headlineContent = {
                            Text(
                                text = chapter.title,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                color = if (isSelected) 
                                    MaterialTheme.colorScheme.primary 
                                else 
                                    MaterialTheme.colorScheme.onSurface
                            )
                        },
                        leadingContent = if (isSelected) {
                            {
                                Icon(
                                    imageVector = Icons.Default.PlayArrow,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.primary
                                )
                            }
                        } else null,
                        modifier = Modifier
                            .clickable { onChapterClick(chapter) }
                            .padding(start = (chapter.level * 16).dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun ReaderSettingsSheet() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
            .padding(bottom = 32.dp)
    ) {
        Text(
            text = "阅读设置",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        // 字体大小
        Text(
            text = "字体大小",
            style = MaterialTheme.typography.labelLarge
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = { }) {
                Icon(Icons.Default.Remove, "减小")
            }
            Text(
                text = "18",
                style = MaterialTheme.typography.titleMedium
            )
            IconButton(onClick = { }) {
                Icon(Icons.Default.Add, "增大")
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        // 主题颜色
        Text(
            text = "背景主题",
            style = MaterialTheme.typography.labelLarge
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            listOf(
                Color.White to "白色",
                Color(0xFFF5F5DC) to "米色",
                Color(0xFFE8F5E9) to "护眼",
                Color(0xFF212121) to "夜间"
            ).forEach { (color, name) ->
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(color)
                            .clickable { }
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = name,
                        style = MaterialTheme.typography.labelSmall
                    )
                }
            }
        }
    }
}
