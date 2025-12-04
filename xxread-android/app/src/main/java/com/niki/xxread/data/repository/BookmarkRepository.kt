package com.niki.xxread.data.repository

import com.niki.xxread.data.dao.BookmarkDao
import com.niki.xxread.data.model.Bookmark
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BookmarkRepository @Inject constructor(
    private val bookmarkDao: BookmarkDao
) {
    
    fun getBookmarksByBookId(bookId: Long): Flow<List<Bookmark>> = 
        bookmarkDao.getBookmarksByBookId(bookId)
    
    suspend fun getBookmarksByBookIdSync(bookId: Long): List<Bookmark> = 
        bookmarkDao.getBookmarksByBookIdSync(bookId)
    
    suspend fun getBookmarkById(bookmarkId: Long): Bookmark? = 
        bookmarkDao.getBookmarkById(bookmarkId)
    
    suspend fun getBookmarkByPage(bookId: Long, pageNumber: Int): Bookmark? = 
        bookmarkDao.getBookmarkByPage(bookId, pageNumber)
    
    suspend fun getBookmarksCount(bookId: Long): Int = 
        bookmarkDao.getBookmarksCount(bookId)
    
    suspend fun insertBookmark(bookmark: Bookmark): Long = 
        bookmarkDao.insertBookmark(bookmark)
    
    suspend fun updateBookmark(bookmark: Bookmark) = 
        bookmarkDao.updateBookmark(bookmark)
    
    suspend fun deleteBookmark(bookmark: Bookmark) = 
        bookmarkDao.deleteBookmark(bookmark)
    
    suspend fun deleteBookmarkById(bookmarkId: Long) = 
        bookmarkDao.deleteBookmarkById(bookmarkId)
    
    suspend fun deleteBookmarksByBookId(bookId: Long) = 
        bookmarkDao.deleteBookmarksByBookId(bookId)
    
    suspend fun isPageBookmarked(bookId: Long, pageNumber: Int): Boolean = 
        bookmarkDao.isPageBookmarked(bookId, pageNumber)
    
    suspend fun toggleBookmark(bookId: Long, pageNumber: Int, note: String = ""): Boolean {
        val existing = bookmarkDao.getBookmarkByPage(bookId, pageNumber)
        return if (existing != null) {
            bookmarkDao.deleteBookmark(existing)
            false // 返回 false 表示书签已删除
        } else {
            bookmarkDao.insertBookmark(Bookmark(bookId = bookId, pageNumber = pageNumber, note = note))
            true // 返回 true 表示书签已添加
        }
    }
}
