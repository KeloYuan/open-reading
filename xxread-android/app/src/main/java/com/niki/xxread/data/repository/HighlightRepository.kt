package com.niki.xxread.data.repository

import com.niki.xxread.data.dao.HighlightDao
import com.niki.xxread.data.model.Highlight
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class HighlightRepository @Inject constructor(
    private val highlightDao: HighlightDao
) {
    
    fun getHighlightsByBookId(bookId: Long): Flow<List<Highlight>> = 
        highlightDao.getHighlightsByBookId(bookId)
    
    suspend fun getHighlightsByBookIdSync(bookId: Long): List<Highlight> = 
        highlightDao.getHighlightsByBookIdSync(bookId)
    
    fun getHighlightsByPage(bookId: Long, pageNumber: Int): Flow<List<Highlight>> = 
        highlightDao.getHighlightsByPage(bookId, pageNumber)
    
    suspend fun getHighlightsByPageSync(bookId: Long, pageNumber: Int): List<Highlight> = 
        highlightDao.getHighlightsByPageSync(bookId, pageNumber)
    
    suspend fun getHighlightById(highlightId: Long): Highlight? = 
        highlightDao.getHighlightById(highlightId)
    
    suspend fun getHighlightsCount(bookId: Long): Int = 
        highlightDao.getHighlightsCount(bookId)
    
    fun getHighlightsWithNotes(bookId: Long): Flow<List<Highlight>> = 
        highlightDao.getHighlightsWithNotes(bookId)
    
    suspend fun insertHighlight(highlight: Highlight): Long = 
        highlightDao.insertHighlight(highlight)
    
    suspend fun updateHighlight(highlight: Highlight) = 
        highlightDao.updateHighlight(highlight)
    
    suspend fun updateHighlightNote(highlightId: Long, note: String) = 
        highlightDao.updateHighlightNote(highlightId, note)
    
    suspend fun updateHighlightColor(highlightId: Long, color: Long) = 
        highlightDao.updateHighlightColor(highlightId, color)
    
    suspend fun deleteHighlight(highlight: Highlight) = 
        highlightDao.deleteHighlight(highlight)
    
    suspend fun deleteHighlightById(highlightId: Long) = 
        highlightDao.deleteHighlightById(highlightId)
    
    suspend fun deleteHighlightsByBookId(bookId: Long) = 
        highlightDao.deleteHighlightsByBookId(bookId)
}
