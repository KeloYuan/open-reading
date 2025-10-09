@echo off
echo ========================================
echo 解锁并清理 Gradle Native 文件
echo ========================================

echo.
echo [1/4] 停止所有 Gradle daemon...
cd android
call gradlew --stop
cd ..

echo.
echo [2/4] 终止所有 Java 进程...
taskkill /F /IM java.exe 2>nul
taskkill /F /IM javaw.exe 2>nul

echo.
echo [3/4] 等待 3 秒...
timeout /t 3 /nobreak >nul

echo.
echo [4/4] 删除被锁定的文件...
rmdir /s /q "%USERPROFILE%\.gradle\native" 2>nul
rmdir /s /q "%USERPROFILE%\.gradle\caches" 2>nul

echo.
echo ========================================
echo 清理完成！现在运行 flutter clean...
echo ========================================
call flutter clean

echo.
echo ========================================
echo 完成！现在可以运行: flutter run
echo ========================================
echo.
pause

