#!/bin/bash
set -e

# Clone Flutter SDK if not available in environment
if [ ! -d "$HOME/flutter" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable $HOME/flutter --depth 1
fi

export PATH="$HOME/flutter/bin:$PATH"

echo "Flutter version:"
flutter --version

echo "Fetching packages..."
flutter pub get

# Setup oauth credentials placeholder for web build if missing
if [ ! -f "lib/shared/services/oauth_credentials.dart" ]; then
  echo "Setting up dummy oauth_credentials.dart for web compilation..."
  cp lib/shared/services/oauth_credentials.example.dart lib/shared/services/oauth_credentials.dart
fi

echo "Building Flutter Web (release)..."
flutter build web --release

echo "Vercel Build Complete!"
