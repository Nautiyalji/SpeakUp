#!/bin/bash

# 1. Clone Flutter if it doesn't exist (using depth 1 for speed)
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# 2. Add flutter to PATH
export PATH="$PATH:$(pwd)/flutter/bin"

# 3. Build for web with environment variables
echo "Building Flutter Web..."
flutter build web --release \
  --dart-define=BASE_URL=$BASE_URL \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
