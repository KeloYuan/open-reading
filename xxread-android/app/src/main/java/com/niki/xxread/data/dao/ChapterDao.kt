package com.niki.xxread.data.dao

import androidx.room.*
import com.niki.xxread.data.model.Chapter
import kotlinx.coroutines.flow.Flow

@Dao
interface ChapterDao {
    
    @Query("SELECT * FROM chapters WHERE bookId = :bookId ORDER BY `order`")
    fun getChaptersByBookId(bookId: Long): Flow<List<Chapter>>
    
    @Query("SELECT * FROM chapters WHERE bookId = :bookId ORDER BY `order`")
    suspend fun getChaptersByBookIdSync(bookId: Long): List<Chapter>
    
    @Query("SELECT * FROM chapters WHERE id = :chapterId")
    suspend fun getChapterById(chapterId: Long): Chapter?
    
    @Query("SELECT * FROM chapters WHERE bookId = :bookId AND startPage <= :page ORDER BY startPage DESC LIMIT 1")
    suspend fun getChapterByPage(bookId: Long, page: Int): Chapter?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertChapter(chapter: Chapter): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertChapters(chapters: List<Chapter>)
    
    @Update
    suspend fun updateChapter(chapter: Chapter)
    
    @Delete
    suspend fun deleteChapter(chapter: Chapter)
    
    @Query("DELETE FROM chapters WHERE bookId = :bookId")
    suspend fun deleteChaptersByBookId(bookId: Long)
}
