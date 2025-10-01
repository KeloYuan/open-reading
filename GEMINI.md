# GEMINI.md

This file provides guidance to the Gemini model when working with the xxread codebase.

## Project Summary

`xxread` (小元读书) is a cross-platform e-book reader built with Flutter. It is designed to be an elegant application supporting EPUB, TXT, and PDF formats. The application runs on mobile (Android/iOS) and desktop (Windows, macOS, Linux).

Key features include:
- Local book importing and management.
- Tracking of reading progress.
- Bookmarking functionality.
- Reading statistics and data visualization.
- A responsive user interface that adapts to different screen sizes.

## Codebase Architecture

The project follows a standard layered architecture to separate concerns:

1.  **Models (`lib/models/`)**: Contains the data structures for the application, such as `Book`, `Bookmark`, and `ReadingStats`.
2.  **Services (`lib/services/`)**: Handles business logic, data persistence, and file operations.
    -   `database_service.dart`: Manages the SQLite database connection.
    -   `book_dao.dart` & `reading_stats_dao.dart`: Data Access Objects for interacting with the database tables.
    -   `book_import_service.dart`: Logic for importing and processing book files.
3.  **Pages/UI (`lib/pages/`)**: Contains the Flutter widgets and screens that form the user interface. The UI is responsive, adapting from a bottom navigation bar on mobile to a side rail on desktop.
4.  **Utilities (`lib/utils/`)**: Provides helper functions and extensions, for example, for responsive design (`responsive_helper.dart`).

## Technical Stack & Key Dependencies

-   **Framework**: Flutter
-   **State Management**: `provider` is used, primarily for theme management (`ThemeNotifier`).
-   **Database**: `sqflite` for mobile and `sqflite_common_ffi` for desktop, providing a cross-platform SQLite solution.
-   **E-book Parsing**: `epubx` is used to process and read EPUB files.
-   **File Handling**: `file_picker` for importing books and `path_provider` for managing file system paths.
-   **Settings Persistence**: `shared_preferences` is used to save user settings like the current theme.
-   **UI Components**: `fl_chart` for displaying reading statistics charts and `page_flip` for the reading animation.

## How to Run the Project

Standard Flutter commands are used for development.

-   **Install dependencies**:
    ```bash
    flutter pub get
    ```
-   **Run the app (e.g., on the current platform)**:
    ```bash
    flutter run
    ```
-   **Run on a specific platform (e.g., Windows)**:
    ```bash
    flutter run -d windows
    ```
-   **Build the app for production (e.g., for Web)**:
    ```bash
    flutter build web
    ```
-   **Run tests**:
    ```bash
    flutter test
    ```
-   **Analyze the code**:
    ```bash
    flutter analyze
    ```
