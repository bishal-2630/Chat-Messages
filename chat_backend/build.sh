#!/bin/bash

# Build and Deploy Script for Chat Messages App
# This script builds the Flutter web app and copies files to Django

echo "Building Flutter web app..."
cd ../chat_messages
flutter build web --release

echo "Copying files to Django backend..."
cd ../chat_backend

# Copy all static files
cp -r ../chat_messages/build/web/* ./static/

# Copy index.html to templates (will be overwritten with Django template version)
cp ../chat_messages/build/web/index.html ./templates/index.html

# Update index.html to use Django static tags
cat > ./templates/index.html << 'EOF'
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
EOF

echo "Build complete! Ready to deploy."
echo "Run: vercel --prod"
