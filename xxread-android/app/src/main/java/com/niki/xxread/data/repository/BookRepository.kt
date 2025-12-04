package com.niki.xxread.data.repository

import com.niki.xxread.data.dao.BookDao
import com.niki.xxread.data.model.Book
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BookRepository @Inject constructor(
    private val bookDao: BookDao
) {
    
    fun getAllBooks(): Flow<List<Book>> = bookDao.getAllBooks()
    
    fun getAllBooksByImportDate(): Flow<List<Book>> = bookDao.getAllBooksByImportDate()
    
    fun getBookByIdFlow(bookId: Long): Flow<Book?> = bookDao.getBookByIdFlow(bookId)
    
    suspend fun getBookById(bookId: Long): Book? = bookDao.getBookById(bookId)
    
    suspend fun getBookByFilePath(filePath: String): Book? = bookDao.getBookByFilePath(filePath)
    
    suspend fun getBooksCount(): Int = bookDao.getBooksCount()
    
    fun getBooksCountFlow(): Flow<Int> = bookDao.getBooksCountFlow()
    
    suspend fun insertBook(book: Book): Long = bookDao.insertBook(book)
    
    suspend fun updateBook(book: Book) = bookDao.updateBook(book)
    
    suspend fun updateBookProgress(bookId: Long, currentPage: Int) = 
        bookDao.updateBookProgress(bookId, currentPage)
    
    suspend fun updateBookTotalPages(bookId: Long, totalPages: Int) = 
        bookDao.updateBookTotalPages(bookId, totalPages)
    
    suspend fun updateReadingProgress(bookId: Long, progress: Float) =
        bookDao.updateReadingProgress(bookId, progress)
    
    suspend fun updateBookCover(bookId: Long, coverPath: String?) =
        bookDao.updateBookCover(bookId, coverPath)
    
    suspend fun deleteBook(book: Book) = bookDao.deleteBook(book)
    
    suspend fun deleteBookById(bookId: Long) = bookDao.deleteBookById(bookId)
    
    fun searchBooks(query: String): Flow<List<Book>> = bookDao.searchBooks(query)
    
    fun getRecentBooks(limit: Int = 10): Flow<List<Book>> = bookDao.getRecentBooks(limit)
}
