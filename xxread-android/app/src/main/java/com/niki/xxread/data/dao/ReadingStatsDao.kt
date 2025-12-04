package com.niki.xxread.data.dao

import androidx.room.*
import com.niki.xxread.data.model.ReadingStats
import com.niki.xxread.data.model.ReadingSession
import kotlinx.coroutines.flow.Flow

@Dao
interface ReadingStatsDao {
    
    // ========== ReadingStats ==========
    
    @Query("SELECT * FROM reading_stats WHERE bookId = :bookId ORDER BY date DESC")
    fun getStatsByBookId(bookId: Long): Flow<List<ReadingStats>>
    
    @Query("SELECT * FROM reading_stats WHERE date >= :startDate AND date <= :endDate ORDER BY date")
    fun getStatsByDateRange(startDate: Long, endDate: Long): Flow<List<ReadingStats>>
    
    @Query("SELECT SUM(readingTimeMinutes) FROM reading_stats WHERE bookId = :bookId")
    suspend fun getTotalReadingTime(bookId: Long): Int?
    
    @Query("SELECT SUM(readingTimeMinutes) FROM reading_stats")
    suspend fun getTotalReadingTimeAll(): Int?
    
    @Query("SELECT SUM(readingTimeMinutes) FROM reading_stats WHERE date >= :startDate AND date <= :endDate")
    suspend fun getReadingTimeByDateRange(startDate: Long, endDate: Long): Int?
    
    @Query("SELECT SUM(pagesRead) FROM reading_stats WHERE bookId = :bookId")
    suspend fun getTotalPagesRead(bookId: Long): Int?
    
    @Query("SELECT * FROM reading_stats WHERE bookId = :bookId AND date = :date LIMIT 1")
    suspend fun getStatsByDate(bookId: Long, date: Long): ReadingStats?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertStats(stats: ReadingStats): Long
    
    @Update
    suspend fun updateStats(stats: ReadingStats)
    
    @Query("DELETE FROM reading_stats WHERE bookId = :bookId")
    suspend fun deleteStatsByBookId(bookId: Long)
    
    // ========== ReadingSession ==========
    
    @Query("SELECT * FROM reading_sessions WHERE bookId = :bookId ORDER BY startTime DESC")
    fun getSessionsByBookId(bookId: Long): Flow<List<ReadingSession>>
    
    @Query("SELECT * FROM reading_sessions WHERE id = :sessionId")
    suspend fun getSessionById(sessionId: Long): ReadingSession?
    
    @Query("SELECT * FROM reading_sessions WHERE bookId = :bookId AND endTime IS NULL ORDER BY startTime DESC LIMIT 1")
    suspend fun getActiveSession(bookId: Long): ReadingSession?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: ReadingSession): Long
    
    @Update
    suspend fun updateSession(session: ReadingSession)
    
    @Query("UPDATE reading_sessions SET endTime = :endTime, endPage = :endPage WHERE id = :sessionId")
    suspend fun endSession(sessionId: Long, endTime: Long, endPage: Int)
    
    @Query("DELETE FROM reading_sessions WHERE bookId = :bookId")
    suspend fun deleteSessionsByBookId(bookId: Long)
    
    // ========== 统计聚合查询 ==========
    
    @Query("""
        SELECT SUM(readingTimeMinutes) as totalMinutes, SUM(pagesRead) as totalPages, COUNT(DISTINCT bookId) as booksCount
        FROM reading_stats
        WHERE date >= :startDate AND date <= :endDate
    """)
    suspend fun getAggregatedStats(startDate: Long, endDate: Long): AggregatedStats?
}

data class AggregatedStats(
    val totalMinutes: Int?,
    val totalPages: Int?,
    val booksCount: Int?
)
