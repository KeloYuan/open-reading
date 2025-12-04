package com.niki.xxread.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * 章节数据模型
 */
@Entity(
    tableName = "chapters",
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
data class Chapter(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val bookId: Long,
    val title: String,
    val startPage: Int = 0,
    val endPage: Int = 0,
    val level: Int = 0, // 章节层级，0=一级章节
    val order: Int = 0, // 章节顺序
    val contentFileName: String? = null, // EPUB章节文件名
    val anchor: String? = null, // EPUB锚点
    val href: String? = null // EPUB链接
)
