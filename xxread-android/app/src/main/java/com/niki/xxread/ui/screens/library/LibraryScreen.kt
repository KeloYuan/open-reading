package com.niki.xxread.ui.screens.library

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.niki.xxread.data.model.Book
import java.io.File
import java.io.FileOutputStream

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
    viewModel: LibraryViewModel = hiltViewModel(),
    onBookClick: (Long) -> Unit,
    onBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    
    var showSortMenu by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf<Book?>(null) }
    var searchActive by remember { mutableStateOf(false) }
    
    // 文件选择器
    val filePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        uri?.let {
            handleFileImport(context, uri, viewModel)
        }
    }
    
    Scaffold(
        topBar = {
            if (searchActive) {
                SearchBar(
                    query = uiState.searchQuery,
                    onQueryChange = { viewModel.search(it) },
                    onSearch = { searchActive = false },
                    active = true,
                    onActiveChange = { searchActive = it },
                    placeholder = { Text("搜索书籍...") },
                    leadingIcon = {
                        IconButton(onClick = { searchActive = false }) {
                            Icon(Icons.Default.ArrowBack, "返回")
                        }
                    },
                    trailingIcon = {
                        if (uiState.searchQuery.isNotEmpty()) {
                            IconButton(onClick = { viewModel.search("") }) {
                                Icon(Icons.Default.Clear, "清除")
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    // 搜索建议
                }
            } else {
                TopAppBar(
                    title = { Text("书库", fontWeight = FontWeight.Bold) },
                    actions = {
                        IconButton(onClick = { searchActive = true }) {
                            Icon(Icons.Outlined.Search, "搜索")
                        }
                        
                        Box {
                            IconButton(onClick = { showSortMenu = true }) {
                                Icon(Icons.Default.Sort, "排序")
                            }
                            
                            DropdownMenu(
                                expanded = showSortMenu,
                                onDismissRequest = { showSortMenu = false }
                            ) {
                                SortOrder.entries.forEach { order ->
                                    DropdownMenuItem(
                                        text = {
                                            Row(
                                                verticalAlignment = Alignment.CenterVertically
                                            ) {
                                                if (uiState.sortOrder == order) {
                                                    Icon(
                                                        Icons.Default.Check,
                                                        contentDescription = null,
                                                        modifier = Modifier.size(20.dp)
                                                    )
                                                    Spacer(modifier = Modifier.width(8.dp))
                                                }
                                                Text(
                                                    when (order) {
                                                        SortOrder.IMPORT_DATE -> "导入时间"
                                                        SortOrder.TITLE -> "书名"
                                                        SortOrder.AUTHOR -> "作者"
                                                        SortOrder.LAST_READ -> "最近阅读"
                                                    }
                                                )
                                            }
                                        },
                                        onClick = {
                                            viewModel.setSortOrder(order)
                                            showSortMenu = false
                                        }
                                    )
                                }
                            }
                        }
                    }
                )
            }
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = {
                    filePickerLauncher.launch(
                        arrayOf(
                            "application/epub+zip",
                            "application/pdf",
                            "text/plain",
                            "application/x-mobipocket-ebook"
                        )
                    )
                },
                icon = { Icon(Icons.Default.Add, "添加") },
                text = { Text("导入书籍") }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (uiState.isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center)
                )
            } else if (uiState.books.isEmpty()) {
                EmptyLibrary(
                    modifier = Modifier.align(Alignment.Center),
                    onImport = {
                        filePickerLauncher.launch(
                            arrayOf(
                                "application/epub+zip",
                                "application/pdf",
                                "text/plain"
                            )
                        )
                    }
                )
            } else {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(minSize = 140.dp),
                    contentPadding = PaddingValues(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(uiState.books, key = { it.id }) { book ->
                        BookGridItem(
                            book = book,
                            onClick = { onBookClick(book.id) },
                            onLongClick = { showDeleteDialog = book }
                        )
                    }
                }
            }
            
            // 导入进度
            if (uiState.isImporting) {
                AlertDialog(
                    onDismissRequest = { },
                    title = { Text("导入中") },
                    text = {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            CircularProgressIndicator()
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(uiState.importProgress ?: "正在处理...")
                        }
                    },
                    confirmButton = { }
                )
            }
        }
    }
    
    // 删除确认对话框
    showDeleteDialog?.let { book ->
        AlertDialog(
            onDismissRequest = { showDeleteDialog = null },
            title = { Text("删除书籍") },
            text = { Text("确定要删除《${book.title}》吗？此操作不可撤销。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteBook(book)
                        showDeleteDialog = null
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("删除")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = null }) {
                    Text("取消")
                }
            }
        )
    }
    
    // 错误提示
    uiState.error?.let { error ->
        LaunchedEffect(error) {
            // 显示错误 Snackbar
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BookGridItem(
    book: Book,
    onClick: () -> Unit,
    onLongClick: () -> Unit
) {
    val haptic = LocalHapticFeedback.current
    
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .combinedClickable(
                onClick = onClick,
                onLongClick = {
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    onLongClick()
                }
            ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Column {
            // 封面
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .clip(RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp)),
                contentAlignment = Alignment.Center
            ) {
                if (book.coverImagePath != null && File(book.coverImagePath).exists()) {
                    AsyncImage(
                        model = File(book.coverImagePath),
                        contentDescription = book.title,
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                } else {
                    Surface(
                        modifier = Modifier.fillMaxSize(),
                        color = MaterialTheme.colorScheme.secondaryContainer
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(
                                imageVector = Icons.Default.Book,
                                contentDescription = null,
                                modifier = Modifier.size(48.dp),
                                tint = MaterialTheme.colorScheme.onSecondaryContainer
                            )
                        }
                    }
                }
                
                // 格式标签
                Surface(
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(8.dp),
                    shape = RoundedCornerShape(4.dp),
                    color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.9f)
                ) {
                    Text(
                        text = book.format.uppercase(),
                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
                
                // 阅读进度
                if (book.readingProgress > 0) {
                    LinearProgressIndicator(
                        progress = { book.readingProgress },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(3.dp)
                            .align(Alignment.BottomCenter),
                        color = MaterialTheme.colorScheme.primary
                    )
                }
            }
            
            // 书籍信息
            Column(
                modifier = Modifier.padding(12.dp)
            ) {
                Text(
                    text = book.title,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    minLines = 2
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = book.author,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
private fun EmptyLibrary(
    modifier: Modifier = Modifier,
    onImport: () -> Unit
) {
    Column(
        modifier = modifier.padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.LibraryBooks,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f)
        )
        Spacer(modifier = Modifier.height(24.dp))
        Text(
            text = "书库是空的",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Medium
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "导入 EPUB、PDF 或 TXT 格式的电子书",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.height(32.dp))
        Button(onClick = onImport) {
            Icon(Icons.Default.Add, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("导入书籍")
        }
    }
}

private fun handleFileImport(
    context: Context,
    uri: Uri,
    viewModel: LibraryViewModel
) {
    try {
        // 获取文件名
        val cursor = context.contentResolver.query(uri, null, null, null, null)
        var fileName = "unknown"
        cursor?.use {
            if (it.moveToFirst()) {
                val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    fileName = it.getString(nameIndex)
                }
            }
        }
        
        // 确定格式
        val format = when {
            fileName.endsWith(".epub", ignoreCase = true) -> "epub"
            fileName.endsWith(".pdf", ignoreCase = true) -> "pdf"
            fileName.endsWith(".txt", ignoreCase = true) -> "txt"
            fileName.endsWith(".mobi", ignoreCase = true) -> "mobi"
            else -> "unknown"
        }
        
        // 复制文件到应用私有目录
        val booksDir = File(context.filesDir, "books")
        if (!booksDir.exists()) booksDir.mkdirs()
        
        val destFile = File(booksDir, fileName)
        context.contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(destFile).use { output ->
                input.copyTo(output)
            }
        }
        
        // 获取标题（去掉扩展名）
        val title = fileName.substringBeforeLast(".")
        
        viewModel.importBook(uri, title, format, destFile.absolutePath)
        
    } catch (e: Exception) {
        e.printStackTrace()
    }
}
