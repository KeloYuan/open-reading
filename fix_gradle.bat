@echo off
echo ========================================
echo 修复 Gradle 构建问题
echo ========================================

echo.
echo [1/5] 清理 Flutter 缓存...
call flutter clean

echo.
echo [2/5] 删除 Gradle 缓存...
if exist "%USERPROFILE%\.gradle\caches" (
    echo 删除 Gradle 缓存目录...
    rmdir /s /q "%USERPROFILE%\.gradle\caches"
)

echo.
echo [3/5] 删除本地构建文件...
if exist "android\.gradle" (
    rmdir /s /q "android\.gradle"
)
if exist "android\build" (
    rmdir /s /q "android\build"
)
if exist "android\app\build" (
    rmdir /s /q "android\app\build"
)

echo.
echo [4/5] 重新获取依赖...
call flutter pub get

echo.
echo [5/5] 完成！
echo.
echo 现在可以尝试运行: flutter run
echo.
pause

