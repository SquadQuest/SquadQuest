#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd "${CI_PRIMARY_REPOSITORY_PATH}" # change working directory to the root of your cloned repo.

# Place secrets Xcode Cloud secret environment variables
echo "Setting up environment..."
echo "${FLUTTER_ENV_BASE64}" | base64 -d >./.env
echo "${GOOGLE_SERVICES_BASE64}" | base64 -d >./ios/Runner/GoogleService-Info.plist
cat .env

# Write version from tag
if [ -n "${CI_TAG}" ]; then
    BUILD_NUMBER="$(git ls-remote origin | grep -c 'refs/tags/v')"
    echo "Setting version to ${CI_TAG#v}+${BUILD_NUMBER}"
    sed -i '' "s/^version:.*/version: ${CI_TAG#v}+${BUILD_NUMBER}/" pubspec.yaml
fi

# Install Flutter using fvm
curl -fsSL https://fvm.app/install.sh | bash
fvm install
fvm use --skip-pub-get

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
fvm flutter precache --ios

# Install Flutter dependencies.
fvm flutter pub get

# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Install CocoaPods dependencies.
cd ios && pod install # run `pod install` in the `ios` directory.

exit 0
