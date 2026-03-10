@echo off
REM Secenek B: versionName degistirdikten sonra uygulamayi bu script ile calistir.
REM Once version is synced from build.gradle.kts, runs the app.
cd /d "%~dp0.."
dart run scripts/generate_app_version.dart
if errorlevel 1 exit /b 1
flutter run %*
