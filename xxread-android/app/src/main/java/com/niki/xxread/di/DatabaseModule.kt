package com.niki.xxread.di

import android.content.Context
import com.niki.xxread.data.AppDatabase
import com.niki.xxread.data.dao.*
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    
    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): AppDatabase {
        return AppDatabase.getInstance(context)
    }
    
    @Provides
    @Singleton
    fun provideBookDao(database: AppDatabase): BookDao {
        return database.bookDao()
    }
    
    @Provides
    @Singleton
    fun provideChapterDao(database: AppDatabase): ChapterDao {
        return database.chapterDao()
    }
    
    @Provides
    @Singleton
    fun provideBookmarkDao(database: AppDatabase): BookmarkDao {
        return database.bookmarkDao()
    }
    
    @Provides
    @Singleton
    fun provideHighlightDao(database: AppDatabase): HighlightDao {
        return database.highlightDao()
    }
    
    @Provides
    @Singleton
    fun provideReadingStatsDao(database: AppDatabase): ReadingStatsDao {
        return database.readingStatsDao()
    }
}
