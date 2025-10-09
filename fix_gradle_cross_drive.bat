@echo off
echo ========================================
echo 修复 Gradle 跨驱动器问题
echo ========================================
echo.

echo 此脚本将执行以下操作：
echo 1. 设置 PUB_CACHE 环境变量到 F:\flutter_pub_cache
echo 2. 清理现有缓存
echo 3. 重新获取依赖
echo.
pause

echo.
echo [1/6] 创建新的 pub cache 目录...
if not exist "F:\flutter_pub_cache" mkdir F:\flutter_pub_cache

echo.
echo [2/6] 停止 Gradle daemon...
cd android
call gradlew --stop 2>nul
cd ..

echo.
echo [3/6] 清理项目...
call flutter clean

echo.
echo [4/6] 设置环境变量 PUB_CACHE...
setx PUB_CACHE "F:\flutter_pub_cache"
set PUB_CACHE=F:\flutter_pub_cache

echo.
echo [5/6] 重新获取 Flutter 依赖...
call flutter pub get

echo.
echo [6/6] 重新获取 Android 依赖...
cd android
call gradlew --refresh-dependencies
cd ..

echo.
echo ========================================
echo 完成！
echo ========================================
echo.
echo 注意：
echo 1. PUB_CACHE 已永久设置为: F:\flutter_pub_cache
echo 2. 请重启命令行窗口使环境变量生效
echo 3. 之后可以删除旧的缓存: C:\Users\niki\AppData\Local\Pub\Cache
echo.
echo 现在可以运行: flutter run
echo.
pause



