package com.niki.xxread.service

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.niki.xxread.data.model.Book
import com.niki.xxread.data.model.Chapter
import com.niki.xxread.data.repository.BookRepository
import com.niki.xxread.data.repository.ChapterRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BookImportService @Inject constructor(
    @ApplicationContext private val context: Context,
    private val bookRepository: BookRepository,
    private val chapterRepository: ChapterRepository
) {
    
    private val booksDir by lazy {
        File(context.filesDir, "books").also { if (!it.exists()) it.mkdirs() }
    }
    
    private val coversDir by lazy {
        File(context.filesDir, "covers").also { if (!it.exists()) it.mkdirs() }
    }
    
    data class ImportResult(
        val success: Boolean,
        val book: Book? = null,
        val error: String? = null
    )
    
    /**
     * 导入书籍
     */
    suspend fun importBook(uri: Uri): ImportResult = withContext(Dispatchers.IO) {
        try {
            // 获取文件信息
            val (fileName, fileSize) = getFileInfo(uri)
            
            // 检查是否已导入
            val existingBook = bookRepository.getBookByFilePath(getDestFilePath(fileName))
            if (existingBook != null) {
                return@withContext ImportResult(
                    success = false,
                    error = "该书籍已存在于书库中"
                )
            }
            
            // 确定格式
            val format = getFormat(fileName)
            if (format == "unknown") {
                return@withContext ImportResult(
                    success = false,
                    error = "不支持的文件格式"
                )
            }
            
            // 复制文件到应用目录
            val destFile = copyFileToApp(uri, fileName)
            
            // 计算内容哈希
            val contentHash = calculateHash(destFile)
            
            // 获取书籍标题（去掉扩展名）
            val title = fileName.substringBeforeLast(".")
            
            // 创建书籍记录
            val book = Book(
                title = title,
                filePath = destFile.absolutePath,
                format = format,
                contentHash = contentHash,
                fileModifiedTime = destFile.lastModified()
            )
            
            val bookId = bookRepository.insertBook(book)
            val savedBook = book.copy(id = bookId)
            
            // 解析章节（如果是TXT）
            if (format == "txt") {
                val chapters = parseTxtChapters(destFile, bookId)
                if (chapters.isNotEmpty()) {
                    chapterRepository.insertChapters(chapters)
                }
            }
            
            // TODO: 解析EPUB章节和封面
            // TODO: 解析PDF目录
            
            ImportResult(success = true, book = savedBook)
            
        } catch (e: Exception) {
            e.printStackTrace()
            ImportResult(success = false, error = e.message ?: "导入失败")
        }
    }
    
    private fun getFileInfo(uri: Uri): Pair<String, Long> {
        var fileName = "unknown"
        var fileSize = 0L
        
        context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                
                if (nameIndex >= 0) {
                    fileName = cursor.getString(nameIndex)
                }
                if (sizeIndex >= 0) {
                    fileSize = cursor.getLong(sizeIndex)
                }
            }
        }
        
        return fileName to fileSize
    }
    
    private fun getFormat(fileName: String): String {
        return when {
            fileName.endsWith(".epub", ignoreCase = true) -> "epub"
            fileName.endsWith(".pdf", ignoreCase = true) -> "pdf"
            fileName.endsWith(".txt", ignoreCase = true) -> "txt"
            fileName.endsWith(".mobi", ignoreCase = true) -> "mobi"
            else -> "unknown"
        }
    }
    
    private fun getDestFilePath(fileName: String): String {
        return File(booksDir, fileName).absolutePath
    }
    
    private fun copyFileToApp(uri: Uri, fileName: String): File {
        val destFile = File(booksDir, fileName)
        
        // 如果文件已存在，添加时间戳
        val finalFile = if (destFile.exists()) {
            val baseName = fileName.substringBeforeLast(".")
            val extension = fileName.substringAfterLast(".", "")
            File(booksDir, "${baseName}_${System.currentTimeMillis()}.$extension")
        } else {
            destFile
        }
        
        context.contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(finalFile).use { output ->
                input.copyTo(output)
            }
        }
        
        return finalFile
    }
    
    private fun calculateHash(file: File): String {
        val digest = MessageDigest.getInstance("MD5")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            var read: Int
            while (input.read(buffer).also { read = it } > 0) {
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
    
    /**
     * 解析TXT文件章节
     */
    private fun parseTxtChapters(file: File, bookId: Long): List<Chapter> {
        val chapters = mutableListOf<Chapter>()
        
        // 章节匹配正则
        val chapterPatterns = listOf(
            Regex("^第[一二三四五六七八九十百千万零\\d]+[章节卷集部篇回].*"),
            Regex("^Chapter\\s+\\d+.*", RegexOption.IGNORE_CASE),
            Regex("^\\d+\\.\\s+.+"),
            Regex("^[一二三四五六七八九十]+、.+")
        )
        
        val content = file.readText()
        val lines = content.split("\n")
        
        var lineNumber = 0
        var order = 0
        
        for ((index, line) in lines.withIndex()) {
            val trimmedLine = line.trim()
            
            if (trimmedLine.isNotEmpty()) {
                for (pattern in chapterPatterns) {
                    if (pattern.matches(trimmedLine)) {
                        chapters.add(
                            Chapter(
                                bookId = bookId,
                                title = trimmedLine,
                                startPage = index, // 使用行号作为起始位置
                                order = order++
                            )
                        )
                        break
                    }
                }
            }
            
            lineNumber++
        }
        
        return chapters
    }
    
    /**
     * 删除书籍文件
     */
    suspend fun deleteBookFiles(book: Book) = withContext(Dispatchers.IO) {
        try {
            // 删除书籍文件
            File(book.filePath).delete()
            
            // 删除封面文件
            book.coverImagePath?.let { File(it).delete() }
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
