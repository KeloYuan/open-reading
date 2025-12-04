package com.niki.xxread.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * 阅读统计数据模型
 */
@Entity(
    tableName = "reading_stats",
    foreignKeys = [
        ForeignKey(
            entity = Book::class,
            parentColumns = ["id"],
            childColumns = ["bookId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("bookId")]
)
data class ReadingStats(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val bookId: Long,
    val date: Long, // 日期（毫秒时间戳，取当天0点）
    val readingTimeMinutes: Int = 0, // 阅读时长（分钟）
    val pagesRead: Int = 0 // 阅读页数
)

/**
 * 阅读会话 - 记录单次阅读
 */
@Entity(
    tableName = "reading_sessions",
    foreignKeys = [
        ForeignKey(
            entity = Book::class,
            parentColumns = ["id"],
            childColumns = ["bookId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("bookId")]
)
data class ReadingSession(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val bookId: Long,
    val startTime: Long,
    val endTime: Long? = null,
    val startPage: Int,
    val endPage: Int? = null
)
