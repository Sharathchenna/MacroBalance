#!/bin/bash

# Clean everything first
flutter clean
rm -rf ~/Library/Developer/Xcode/DerivedData

# Disable module cache for Xcode
export XCODE_XCCONFIG_FILE=""
export CLANG_MODULES_BUILD_SESSION_FILE=""

# Set Xcode build settings to disable modules
export OTHER_SWIFT_FLAGS="-Xfrontend -disable-modules-validate-system-headers"
export SWIFT_DISABLE_MODULES_VALIDATION=YES
export CLANG_ENABLE_MODULES=NO

# Run Flutter with iOS simulator
flutter run -d "53576DE1-78D3-4E88-A450-5B7816C526CF" 