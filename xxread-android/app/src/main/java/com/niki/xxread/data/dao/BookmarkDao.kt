package com.niki.xxread.data.dao

import androidx.room.*
import com.niki.xxread.data.model.Bookmark
import kotlinx.coroutines.flow.Flow

@Dao
interface BookmarkDao {
    
    @Query("SELECT * FROM bookmarks WHERE bookId = :bookId ORDER BY pageNumber")
    fun getBookmarksByBookId(bookId: Long): Flow<List<Bookmark>>
    
    @Query("SELECT * FROM bookmarks WHERE bookId = :bookId ORDER BY pageNumber")
    suspend fun getBookmarksByBookIdSync(bookId: Long): List<Bookmark>
    
    @Query("SELECT * FROM bookmarks WHERE id = :bookmarkId")
    suspend fun getBookmarkById(bookmarkId: Long): Bookmark?
    
    @Query("SELECT * FROM bookmarks WHERE bookId = :bookId AND pageNumber = :pageNumber LIMIT 1")
    suspend fun getBookmarkByPage(bookId: Long, pageNumber: Int): Bookmark?
    
    @Query("SELECT COUNT(*) FROM bookmarks WHERE bookId = :bookId")
    suspend fun getBookmarksCount(bookId: Long): Int
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBookmark(bookmark: Bookmark): Long
    
    @Update
    suspend fun updateBookmark(bookmark: Bookmark)
    
    @Delete
    suspend fun deleteBookmark(bookmark: Bookmark)
    
    @Query("DELETE FROM bookmarks WHERE id = :bookmarkId")
    suspend fun deleteBookmarkById(bookmarkId: Long)
    
    @Query("DELETE FROM bookmarks WHERE bookId = :bookId")
    suspend fun deleteBookmarksByBookId(bookId: Long)
    
    @Query("SELECT EXISTS(SELECT 1 FROM bookmarks WHERE bookId = :bookId AND pageNumber = :pageNumber)")
    suspend fun isPageBookmarked(bookId: Long, pageNumber: Int): Boolean
}
