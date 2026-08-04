#!/bin/bash
set -e

# Vercel's build image has no Flutter SDK preinstalled, and build/web is no
# longer committed to git, so this installs Flutter fresh and builds the web
# app on every deploy.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter_sdk
export PATH="$PATH:$(pwd)/_flutter_sdk/bin"

flutter config --enable-web
flutter pub get

# `flutter analyze` and `flutter test` were run here for a while. Removed on
# request. They are easy to restore — see git history for
# 20260802 chore(ci): run flutter analyze and test inside the Vercel build.
#
# Worth knowing what is lost: the build below is still a COMPILE gate (set -e,
# so a syntax or type error fails the deploy and cannot reach production), but
# nothing now runs the unit tests in test/, and nothing reports lints. The
# suite was never confirmed green, so nothing regressed by removing it.
flutter build web --release --no-tree-shake-icons
