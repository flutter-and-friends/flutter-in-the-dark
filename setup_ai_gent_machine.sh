#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- 1. Install System Dependencies ---
# This uses 'apt-get' for Debian/Ubuntu. You may need to change this
# for other Linux distributions (e.g., 'sudo dnf install...' on Fedora).
echo "Installing dependencies (git, curl, unzip, bash)..."
sudo apt-get update && sudo apt-get install -y git curl unzip bash

# --- 2. Clone Flutter SDK ---
# Clones the stable branch of Flutter into the home directory.
# If you already have a '~/flutter' directory, this will fail.
# Remove it first if you want a fresh install.
echo "Cloning Flutter repository to ~/flutter..."
git clone https://github.com/flutter/flutter.git -b stable ~/flutter

# --- 3. Configure .bashrc for Permanent PATH Update ---
# Adds the necessary paths to your shell configuration file.
echo "Configuring ~/.bashrc..."
{
  echo ''
  echo '# Add Flutter and Dart package executables to the PATH'
  echo 'export PATH="$PATH:$HOME/flutter/bin"'
  echo 'export PATH="$PATH:$HOME/.pub-cache/bin"'
} >> ~/.bashrc

# --- 4. Update PATH for Current Session ---
# This allows you to run the flutter command immediately in this script.
echo "Updating PATH for current terminal session..."
export PATH="$PATH:$HOME/flutter/bin"
export PATH="$PATH:$HOME/.pub-cache/bin"

# --- 5. Initialize Flutter ---
# Run 'flutter doctor' to download the Dart SDK and check the setup.
echo "Initializing Flutter and downloading Dart SDK..."
flutter doctor -v

# --- 6. Precache Artifacts ---
# Download platform-specific development binaries ahead of time.
echo "Precaching Flutter artifacts..."
flutter precache

# --- 7. Accept Android Licenses (if Android SDK is present) ---
# Note: This step requires the Android SDK to be installed separately.
if [ -d "$ANDROID_SDK_ROOT" ]; then
    echo "Attempting to accept Android licenses..."
    yes | flutter doctor --android-licenses
fi

echo ""
echo "✅ Flutter installation is complete!"
