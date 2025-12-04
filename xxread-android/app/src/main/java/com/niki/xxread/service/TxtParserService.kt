package com.niki.xxread.service

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.nio.charset.Charset
import javax.inject.Inject
import javax.inject.Singleton

/**
 * TXT 文件解析服务
 */
@Singleton
class TxtParserService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    
    /**
     * 页面内容
     */
    data class PageContent(
        val pageNumber: Int,
        val content: String,
        val startOffset: Int,
        val endOffset: Int
    )
    
    /**
     * 分页配置
     */
    data class PaginationConfig(
        val charsPerLine: Int = 35,
        val linesPerPage: Int = 25,
        val fontSize: Float = 18f,
        val lineHeight: Float = 1.5f
    )
    
    /**
     * 读取 TXT 文件内容
     */
    suspend fun readContent(filePath: String): String = withContext(Dispatchers.IO) {
        val file = File(filePath)
        if (!file.exists()) {
            throw IllegalArgumentException("文件不存在: $filePath")
        }
        
        // 检测编码
        val charset = detectCharset(file)
        file.readText(charset)
    }
    
    /**
     * 检测文件编码
     */
    private fun detectCharset(file: File): Charset {
        val bytes = file.inputStream().use { it.readNBytes(4096) }
        
        // 检测 BOM
        if (bytes.size >= 3) {
            if (bytes[0] == 0xEF.toByte() && bytes[1] == 0xBB.toByte() && bytes[2] == 0xBF.toByte()) {
                return Charsets.UTF_8
            }
        }
        if (bytes.size >= 2) {
            if (bytes[0] == 0xFF.toByte() && bytes[1] == 0xFE.toByte()) {
                return Charsets.UTF_16LE
            }
            if (bytes[0] == 0xFE.toByte() && bytes[1] == 0xFF.toByte()) {
                return Charsets.UTF_16BE
            }
        }
        
        // 尝试检测是否为 UTF-8
        if (isValidUtf8(bytes)) {
            return Charsets.UTF_8
        }
        
        // 默认使用 GBK（中文 Windows 常用）
        return try {
            Charset.forName("GBK")
        } catch (e: Exception) {
            Charsets.UTF_8
        }
    }
    
    private fun isValidUtf8(bytes: ByteArray): Boolean {
        var i = 0
        while (i < bytes.size) {
            val b = bytes[i].toInt() and 0xFF
            when {
                b <= 0x7F -> i++
                b in 0xC0..0xDF -> {
                    if (i + 1 >= bytes.size) return false
                    if ((bytes[i + 1].toInt() and 0xC0) != 0x80) return false
                    i += 2
                }
                b in 0xE0..0xEF -> {
                    if (i + 2 >= bytes.size) return false
                    if ((bytes[i + 1].toInt() and 0xC0) != 0x80) return false
                    if ((bytes[i + 2].toInt() and 0xC0) != 0x80) return false
                    i += 3
                }
                b in 0xF0..0xF7 -> {
                    if (i + 3 >= bytes.size) return false
                    if ((bytes[i + 1].toInt() and 0xC0) != 0x80) return false
                    if ((bytes[i + 2].toInt() and 0xC0) != 0x80) return false
                    if ((bytes[i + 3].toInt() and 0xC0) != 0x80) return false
                    i += 4
                }
                else -> return false
            }
        }
        return true
    }
    
    /**
     * 将内容分页
     */
    suspend fun paginate(
        content: String,
        config: PaginationConfig = PaginationConfig()
    ): List<PageContent> = withContext(Dispatchers.Default) {
        val pages = mutableListOf<PageContent>()
        val charsPerPage = config.charsPerLine * config.linesPerPage
        
        var currentOffset = 0
        var pageNumber = 0
        
        while (currentOffset < content.length) {
            val endOffset = minOf(currentOffset + charsPerPage, content.length)
            
            // 尝试在段落结束处断开
            var actualEndOffset = endOffset
            if (endOffset < content.length) {
                // 向前查找段落结束符
                val searchStart = maxOf(currentOffset, endOffset - 100)
                val lastParagraph = content.lastIndexOf('\n', endOffset - 1)
                if (lastParagraph > searchStart) {
                    actualEndOffset = lastParagraph + 1
                }
            }
            
            val pageContent = content.substring(currentOffset, actualEndOffset)
            
            pages.add(
                PageContent(
                    pageNumber = pageNumber,
                    content = pageContent.trim(),
                    startOffset = currentOffset,
                    endOffset = actualEndOffset
                )
            )
            
            currentOffset = actualEndOffset
            pageNumber++
        }
        
        pages
    }
    
    /**
     * 获取指定页面的内容
     */
    suspend fun getPage(
        content: String,
        pageNumber: Int,
        config: PaginationConfig = PaginationConfig()
    ): PageContent? = withContext(Dispatchers.Default) {
        val pages = paginate(content, config)
        pages.getOrNull(pageNumber)
    }
    
    /**
     * 计算总页数
     */
    suspend fun getTotalPages(
        content: String,
        config: PaginationConfig = PaginationConfig()
    ): Int = withContext(Dispatchers.Default) {
        paginate(content, config).size
    }
    
    /**
     * 搜索内容
     */
    suspend fun search(
        content: String,
        query: String,
        config: PaginationConfig = PaginationConfig()
    ): List<SearchResult> = withContext(Dispatchers.Default) {
        if (query.isBlank()) return@withContext emptyList()
        
        val results = mutableListOf<SearchResult>()
        val pages = paginate(content, config)
        
        for (page in pages) {
            var index = page.content.indexOf(query, ignoreCase = true)
            while (index >= 0) {
                // 提取上下文
                val contextStart = maxOf(0, index - 20)
                val contextEnd = minOf(page.content.length, index + query.length + 20)
                val context = page.content.substring(contextStart, contextEnd)
                
                results.add(
                    SearchResult(
                        pageNumber = page.pageNumber,
                        offset = page.startOffset + index,
                        context = context,
                        matchStart = index - contextStart,
                        matchEnd = index - contextStart + query.length
                    )
                )
                
                index = page.content.indexOf(query, index + 1, ignoreCase = true)
            }
        }
        
        results
    }
    
    data class SearchResult(
        val pageNumber: Int,
        val offset: Int,
        val context: String,
        val matchStart: Int,
        val matchEnd: Int
    )
}
