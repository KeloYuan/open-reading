package com.niki.xxread.data.repository

import com.niki.xxread.data.dao.ChapterDao
import com.niki.xxread.data.model.Chapter
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ChapterRepository @Inject constructor(
    private val chapterDao: ChapterDao
) {
    
    fun getChaptersByBookId(bookId: Long): Flow<List<Chapter>> = 
        chapterDao.getChaptersByBookId(bookId)
    
    suspend fun getChaptersByBookIdSync(bookId: Long): List<Chapter> = 
        chapterDao.getChaptersByBookIdSync(bookId)
    
    suspend fun getChapterById(chapterId: Long): Chapter? = 
        chapterDao.getChapterById(chapterId)
    
    suspend fun getChapterByPage(bookId: Long, page: Int): Chapter? = 
        chapterDao.getChapterByPage(bookId, page)
    
    suspend fun insertChapter(chapter: Chapter): Long = 
        chapterDao.insertChapter(chapter)
    
    suspend fun insertChapters(chapters: List<Chapter>) = 
        chapterDao.insertChapters(chapters)
    
    suspend fun updateChapter(chapter: Chapter) = 
        chapterDao.updateChapter(chapter)
    
    suspend fun deleteChapter(chapter: Chapter) = 
        chapterDao.deleteChapter(chapter)
    
    suspend fun deleteChaptersByBookId(bookId: Long) = 
        chapterDao.deleteChaptersByBookId(bookId)
}
