package com.niki.xxread.ui.screens.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.niki.xxread.data.model.Book
import com.niki.xxread.data.repository.BookRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class HomeUiState(
    val recentBooks: List<Book> = emptyList(),
    val totalBooksCount: Int = 0,
    val isLoading: Boolean = true,
    val error: String? = null
)

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val bookRepository: BookRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    
    init {
        loadData()
    }
    
    private fun loadData() {
        viewModelScope.launch {
            combine(
                bookRepository.getRecentBooks(5),
                bookRepository.getBooksCountFlow()
            ) { recentBooks, count ->
                HomeUiState(
                    recentBooks = recentBooks,
                    totalBooksCount = count,
                    isLoading = false
                )
            }.catch { e ->
                _uiState.update { it.copy(error = e.message, isLoading = false) }
            }.collect { state ->
                _uiState.value = state
            }
        }
    }
    
    fun refresh() {
        _uiState.update { it.copy(isLoading = true) }
        loadData()
    }
}
