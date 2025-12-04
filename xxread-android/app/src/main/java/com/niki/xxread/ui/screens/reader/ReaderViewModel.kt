package com.niki.xxread.ui.screens.reader

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.niki.xxread.data.model.*
import com.niki.xxread.data.repository.*
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ReaderUiState(
    val book: Book? = null,
    val chapters: List<Chapter> = emptyList(),
    val bookmarks: List<Bookmark> = emptyList(),
    val highlights: List<Highlight> = emptyList(),
    val currentPage: Int = 0,
    val totalPages: Int = 1,
    val currentChapter: Chapter? = null,
    val pageContent: String = "",
    val isLoading: Boolean = true,
    val error: String? = null,
    val showOverlay: Boolean = false,
    val isCurrentPageBookmarked: Boolean = false
)

@HiltViewModel
class ReaderViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val bookRepository: BookRepository,
    private val chapterRepository: ChapterRepository,
    private val bookmarkRepository: BookmarkRepository,
    private val highlightRepository: HighlightRepository
) : ViewModel() {
    
    private val bookId: Long = checkNotNull(savedStateHandle["bookId"])
    
    private val _uiState = MutableStateFlow(ReaderUiState())
    val uiState: StateFlow<ReaderUiState> = _uiState.asStateFlow()
    
    init {
        loadBook()
        loadChapters()
        loadBookmarks()
        loadHighlights()
    }
    
    private fun loadBook() {
        viewModelScope.launch {
            bookRepository.getBookByIdFlow(bookId).collect { book ->
                book?.let {
                    _uiState.update { state ->
                        state.copy(
                            book = it,
                            currentPage = it.currentPage,
                            totalPages = it.totalPages,
                            isLoading = false
                        )
                    }
                }
            }
        }
    }
    
    private fun loadChapters() {
        viewModelScope.launch {
            chapterRepository.getChaptersByBookId(bookId).collect { chapters ->
                _uiState.update { it.copy(chapters = chapters) }
                updateCurrentChapter()
            }
        }
    }
    
    private fun loadBookmarks() {
        viewModelScope.launch {
            bookmarkRepository.getBookmarksByBookId(bookId).collect { bookmarks ->
                _uiState.update { state ->
                    state.copy(
                        bookmarks = bookmarks,
                        isCurrentPageBookmarked = bookmarks.any { it.pageNumber == state.currentPage }
                    )
                }
            }
        }
    }
    
    private fun loadHighlights() {
        viewModelScope.launch {
            highlightRepository.getHighlightsByBookId(bookId).collect { highlights ->
                _uiState.update { it.copy(highlights = highlights) }
            }
        }
    }
    
    fun goToPage(page: Int) {
        val totalPages = _uiState.value.totalPages
        val newPage = page.coerceIn(0, totalPages - 1)
        
        _uiState.update { state ->
            state.copy(
                currentPage = newPage,
                isCurrentPageBookmarked = state.bookmarks.any { it.pageNumber == newPage }
            )
        }
        
        updateCurrentChapter()
        saveProgress(newPage)
    }
    
    fun nextPage() {
        val current = _uiState.value.currentPage
        val total = _uiState.value.totalPages
        if (current < total - 1) {
            goToPage(current + 1)
        }
    }
    
    fun previousPage() {
        val current = _uiState.value.currentPage
        if (current > 0) {
            goToPage(current - 1)
        }
    }
    
    fun goToChapter(chapter: Chapter) {
        goToPage(chapter.startPage)
    }
    
    private fun updateCurrentChapter() {
        val currentPage = _uiState.value.currentPage
        val chapters = _uiState.value.chapters
        
        val chapter = chapters.lastOrNull { it.startPage <= currentPage }
        _uiState.update { it.copy(currentChapter = chapter) }
    }
    
    private fun saveProgress(page: Int) {
        viewModelScope.launch {
            val totalPages = _uiState.value.totalPages
            val progress = if (totalPages > 0) page.toFloat() / totalPages else 0f
            
            bookRepository.updateBookProgress(bookId, page)
            bookRepository.updateReadingProgress(bookId, progress)
        }
    }
    
    fun toggleOverlay() {
        _uiState.update { it.copy(showOverlay = !it.showOverlay) }
    }
    
    fun hideOverlay() {
        _uiState.update { it.copy(showOverlay = false) }
    }
    
    fun toggleBookmark() {
        viewModelScope.launch {
            val currentPage = _uiState.value.currentPage
            val isBookmarked = bookmarkRepository.toggleBookmark(bookId, currentPage)
            _uiState.update { it.copy(isCurrentPageBookmarked = isBookmarked) }
        }
    }
    
    fun addHighlight(
        selectedText: String,
        startOffset: Int,
        endOffset: Int,
        color: Long = 0xFFFFEB3B
    ) {
        viewModelScope.launch {
            val currentPage = _uiState.value.currentPage
            val currentChapter = _uiState.value.currentChapter
            
            val highlight = Highlight(
                bookId = bookId,
                pageNumber = currentPage,
                selectedText = selectedText,
                startOffset = startOffset,
                endOffset = endOffset,
                color = color,
                chapter = currentChapter?.title ?: ""
            )
            
            highlightRepository.insertHighlight(highlight)
        }
    }
    
    fun deleteHighlight(highlight: Highlight) {
        viewModelScope.launch {
            highlightRepository.deleteHighlight(highlight)
        }
    }
    
    fun updateHighlightNote(highlightId: Long, note: String) {
        viewModelScope.launch {
            highlightRepository.updateHighlightNote(highlightId, note)
        }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
