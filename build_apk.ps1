# Builds the release APK pointed at the deployed Cloud Run backend.
# ALWAYS use this instead of a bare `flutter build apk` — a plain build defaults
# BASE_URL to http://10.0.2.2:8000 (emulator loopback), which is unreachable on a
# real phone, so login and every API call fail.
$ErrorActionPreference = "Stop"
$ApiUrl = "https://kalasetu-api-knzuamsjoq-el.a.run.app"

Set-Location "$PSScriptRoot\app"
Write-Host "Building release APK -> BASE_URL=$ApiUrl" -ForegroundColor Cyan
flutter build apk --release --dart-define=BASE_URL=$ApiUrl

$src = "$PSScriptRoot\app\build\app\outputs\flutter-apk\app-release.apk"
Copy-Item $src "$PSScriptRoot\KalaSetu.apk" -Force
Copy-Item $src "$HOME\Desktop\KalaSetu.apk" -Force
Write-Host "Copied to repo root and Desktop as KalaSetu.apk" -ForegroundColor Green
