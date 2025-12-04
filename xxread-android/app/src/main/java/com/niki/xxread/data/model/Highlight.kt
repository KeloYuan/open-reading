package com.niki.xxread.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * 高亮/划线数据模型
 */
@Entity(
    tableName = "highlights",
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
data class Highlight(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val bookId: Long,
    val pageNumber: Int,
    val selectedText: String,
    val startOffset: Int,
    val endOffset: Int,
    val color: Long = 0xFFFFEB3B, // 默认黄色
    val note: String = "", // 笔记内容
    val chapter: String = "",
    val cfi: String? = null,
    val createTime: Long = System.currentTimeMillis()
)
