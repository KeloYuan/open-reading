package com.niki.xxread.data.dao

import androidx.room.*
import com.niki.xxread.data.model.Book
import kotlinx.coroutines.flow.Flow

@Dao
interface BookDao {
    
    @Query("SELECT * FROM books ORDER BY lastReadTime DESC, importDate DESC")
    fun getAllBooks(): Flow<List<Book>>
    
    @Query("SELECT * FROM books ORDER BY importDate DESC")
    fun getAllBooksByImportDate(): Flow<List<Book>>
    
    @Query("SELECT * FROM books WHERE id = :bookId")
    suspend fun getBookById(bookId: Long): Book?
    
    @Query("SELECT * FROM books WHERE id = :bookId")
    fun getBookByIdFlow(bookId: Long): Flow<Book?>
    
    @Query("SELECT * FROM books WHERE filePath = :filePath LIMIT 1")
    suspend fun getBookByFilePath(filePath: String): Book?
    
    @Query("SELECT COUNT(*) FROM books")
    suspend fun getBooksCount(): Int
    
    @Query("SELECT COUNT(*) FROM books")
    fun getBooksCountFlow(): Flow<Int>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBook(book: Book): Long
    
    @Update
    suspend fun updateBook(book: Book)
    
    @Query("UPDATE books SET currentPage = :currentPage, lastReadTime = :lastReadTime WHERE id = :bookId")
    suspend fun updateBookProgress(bookId: Long, currentPage: Int, lastReadTime: Long = System.currentTimeMillis())
    
    @Query("UPDATE books SET totalPages = :totalPages WHERE id = :bookId")
    suspend fun updateBookTotalPages(bookId: Long, totalPages: Int)
    
    @Query("UPDATE books SET readingProgress = :progress, lastReadTime = :lastReadTime WHERE id = :bookId")
    suspend fun updateReadingProgress(bookId: Long, progress: Float, lastReadTime: Long = System.currentTimeMillis())
    
    @Query("UPDATE books SET coverImagePath = :coverPath WHERE id = :bookId")
    suspend fun updateBookCover(bookId: Long, coverPath: String?)
    
    @Delete
    suspend fun deleteBook(book: Book)
    
    @Query("DELETE FROM books WHERE id = :bookId")
    suspend fun deleteBookById(bookId: Long)
    
    @Query("SELECT * FROM books WHERE title LIKE '%' || :query || '%' OR author LIKE '%' || :query || '%'")
    fun searchBooks(query: String): Flow<List<Book>>
    
    // 获取最近阅读的书籍
    @Query("SELECT * FROM books WHERE lastReadTime IS NOT NULL ORDER BY lastReadTime DESC LIMIT :limit")
    fun getRecentBooks(limit: Int = 10): Flow<List<Book>>
}
