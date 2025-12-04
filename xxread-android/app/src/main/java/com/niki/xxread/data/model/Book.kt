package com.niki.xxread.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * 书籍数据模型
 */
@Entity(tableName = "books")
data class Book(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val title: String,
    val author: String = "未知",
    val filePath: String,
    val format: String, // epub, pdf, txt, etc.
    val currentPage: Int = 0,
    val totalPages: Int = 1,
    val importDate: Long = System.currentTimeMillis(),
    val coverImagePath: String? = null,
    val tableOfContents: String? = null,
    val contentHash: String? = null,
    val fileModifiedTime: Long? = null,
    val lastReadTime: Long? = null,
    val readingProgress: Float = 0f // 0.0 - 1.0
)
