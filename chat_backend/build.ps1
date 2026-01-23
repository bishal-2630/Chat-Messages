# Build and Deploy Script for Chat Messages App (PowerShell)
# This script builds the Flutter web app and copies files to Django

Write-Host "Building Flutter web app..." -ForegroundColor Green
Set-Location ..\chat_messages
flutter build web --release

Write-Host "Copying files to Django backend..." -ForegroundColor Green
Set-Location ..\chat_backend

# Create directories if they don't exist
New-Item -ItemType Directory -Path "static" -Force | Out-Null
New-Item -ItemType Directory -Path "templates" -Force | Out-Null

# Copy all static files
Copy-Item -Path "..\chat_messages\build\web\*" -Destination ".\static\" -Recurse -Force

# Copy index.html template
Copy-Item -Path ".\templates\index.html" -Destination ".\templates\index.html.bak" -Force -ErrorAction SilentlyContinue

# Create Django template version of index.html
@"
{% load static %}
<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="Chat Messages App">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Chat Messages">
  <link rel="apple-touch-icon" href="{% static 'icons/Icon-192.png' %}">
  <link rel="icon" type="image/png" href="{% static 'favicon.png' %}"/>
  <title>Chat Messages</title>
  <link rel="manifest" href="{% static 'manifest.json' %}">
</head>
<body>
  <div id="loading" style="display: flex; justify-content: center; align-items: center; height: 100vh; font-family: sans-serif;">
    <h2>Loading Chat App...</h2>
  </div>
  <script src="{% static 'flutter_bootstrap.js' %}" async></script>
</body>
</html>
"@ | Out-File -FilePath ".\templates\index.html" -Encoding UTF8

Write-Host "Build complete! Ready to deploy." -ForegroundColor Green
Write-Host "Run: vercel --prod" -ForegroundColor Yellow
