package com.niki.xxread.ui.screens.library

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.niki.xxread.data.model.Book
import com.niki.xxread.data.repository.BookRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LibraryUiState(
    val books: List<Book> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null,
    val searchQuery: String = "",
    val sortOrder: SortOrder = SortOrder.IMPORT_DATE,
    val isImporting: Boolean = false,
    val importProgress: String? = null
)

enum class SortOrder {
    IMPORT_DATE,
    TITLE,
    AUTHOR,
    LAST_READ
}

@HiltViewModel
class LibraryViewModel @Inject constructor(
    private val bookRepository: BookRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(LibraryUiState())
    val uiState: StateFlow<LibraryUiState> = _uiState.asStateFlow()
    
    private val _searchQuery = MutableStateFlow("")
    
    init {
        loadBooks()
    }
    
    private fun loadBooks() {
        viewModelScope.launch {
            _searchQuery.flatMapLatest { query ->
                if (query.isBlank()) {
                    bookRepository.getAllBooks()
                } else {
                    bookRepository.searchBooks(query)
                }
            }.catch { e ->
                _uiState.update { it.copy(error = e.message, isLoading = false) }
            }.collect { books ->
                _uiState.update { state ->
                    state.copy(
                        books = sortBooks(books, state.sortOrder),
                        isLoading = false
                    )
                }
            }
        }
    }
    
    fun search(query: String) {
        _searchQuery.value = query
        _uiState.update { it.copy(searchQuery = query) }
    }
    
    fun setSortOrder(order: SortOrder) {
        _uiState.update { state ->
            state.copy(
                sortOrder = order,
                books = sortBooks(state.books, order)
            )
        }
    }
    
    private fun sortBooks(books: List<Book>, order: SortOrder): List<Book> {
        return when (order) {
            SortOrder.IMPORT_DATE -> books.sortedByDescending { it.importDate }
            SortOrder.TITLE -> books.sortedBy { it.title }
            SortOrder.AUTHOR -> books.sortedBy { it.author }
            SortOrder.LAST_READ -> books.sortedByDescending { it.lastReadTime ?: 0 }
        }
    }
    
    fun deleteBook(book: Book) {
        viewModelScope.launch {
            try {
                bookRepository.deleteBook(book)
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.message) }
            }
        }
    }
    
    fun importBook(uri: Uri, title: String, format: String, filePath: String) {
        viewModelScope.launch {
            try {
                _uiState.update { it.copy(isImporting = true, importProgress = "正在导入...") }
                
                val book = Book(
                    title = title,
                    filePath = filePath,
                    format = format
                )
                bookRepository.insertBook(book)
                
                _uiState.update { it.copy(isImporting = false, importProgress = null) }
            } catch (e: Exception) {
                _uiState.update { 
                    it.copy(
                        isImporting = false, 
                        importProgress = null,
                        error = "导入失败: ${e.message}"
                    ) 
                }
            }
        }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
