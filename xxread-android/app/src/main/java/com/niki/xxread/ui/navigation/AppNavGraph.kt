package com.niki.xxread.ui.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import com.niki.xxread.ui.screens.home.HomeScreen
import com.niki.xxread.ui.screens.library.LibraryScreen
import com.niki.xxread.ui.screens.reader.ReaderScreen
import com.niki.xxread.ui.screens.settings.SettingsScreen

@Composable
fun AppNavGraph(
    navController: NavHostController,
    modifier: Modifier = Modifier,
    startDestination: String = Screen.Home.route
) {
    NavHost(
        navController = navController,
        startDestination = startDestination,
        modifier = modifier
    ) {
        // 首页
        composable(Screen.Home.route) {
            HomeScreen(
                onBookClick = { bookId ->
                    navController.navigate(Screen.Reader.createRoute(bookId))
                },
                onNavigateToLibrary = {
                    navController.navigate(Screen.Library.route)
                }
            )
        }
        
        // 书库
        composable(Screen.Library.route) {
            LibraryScreen(
                onBookClick = { bookId ->
                    navController.navigate(Screen.Reader.createRoute(bookId))
                },
                onBack = {
                    navController.popBackStack()
                }
            )
        }
        
        // 设置
        composable(Screen.Settings.route) {
            SettingsScreen()
        }
        
        // 阅读器
        composable(
            route = Screen.Reader.route,
            arguments = listOf(
                navArgument("bookId") { type = NavType.LongType }
            )
        ) { backStackEntry ->
            val bookId = backStackEntry.arguments?.getLong("bookId") ?: return@composable
            ReaderScreen(
                bookId = bookId,
                onBack = {
                    navController.popBackStack()
                }
            )
        }
    }
}
