package com.niki.xxread.data.dao

import androidx.room.*
import com.niki.xxread.data.model.Highlight
import kotlinx.coroutines.flow.Flow

@Dao
interface HighlightDao {
    
    @Query("SELECT * FROM highlights WHERE bookId = :bookId ORDER BY pageNumber, startOffset")
    fun getHighlightsByBookId(bookId: Long): Flow<List<Highlight>>
    
    @Query("SELECT * FROM highlights WHERE bookId = :bookId ORDER BY pageNumber, startOffset")
    suspend fun getHighlightsByBookIdSync(bookId: Long): List<Highlight>
    
    @Query("SELECT * FROM highlights WHERE bookId = :bookId AND pageNumber = :pageNumber ORDER BY startOffset")
    fun getHighlightsByPage(bookId: Long, pageNumber: Int): Flow<List<Highlight>>
    
    @Query("SELECT * FROM highlights WHERE bookId = :bookId AND pageNumber = :pageNumber ORDER BY startOffset")
    suspend fun getHighlightsByPageSync(bookId: Long, pageNumber: Int): List<Highlight>
    
    @Query("SELECT * FROM highlights WHERE id = :highlightId")
    suspend fun getHighlightById(highlightId: Long): Highlight?
    
    @Query("SELECT COUNT(*) FROM highlights WHERE bookId = :bookId")
    suspend fun getHighlightsCount(bookId: Long): Int
    
    @Query("SELECT * FROM highlights WHERE bookId = :bookId AND note != '' ORDER BY createTime DESC")
    fun getHighlightsWithNotes(bookId: Long): Flow<List<Highlight>>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertHighlight(highlight: Highlight): Long
    
    @Update
    suspend fun updateHighlight(highlight: Highlight)
    
    @Query("UPDATE highlights SET note = :note WHERE id = :highlightId")
    suspend fun updateHighlightNote(highlightId: Long, note: String)
    
    @Query("UPDATE highlights SET color = :color WHERE id = :highlightId")
    suspend fun updateHighlightColor(highlightId: Long, color: Long)
    
    @Delete
    suspend fun deleteHighlight(highlight: Highlight)
    
    @Query("DELETE FROM highlights WHERE id = :highlightId")
    suspend fun deleteHighlightById(highlightId: Long)
    
    @Query("DELETE FROM highlights WHERE bookId = :bookId")
    suspend fun deleteHighlightsByBookId(bookId: Long)
}
