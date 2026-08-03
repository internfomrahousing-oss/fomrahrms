#!/bin/bash
set -e

# Vercel's build image has no Flutter SDK preinstalled, and build/web is no
# longer committed to git, so this installs Flutter fresh and builds the web
# app on every deploy.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter_sdk
export PATH="$PATH:$(pwd)/_flutter_sdk/bin"

flutter config --enable-web
flutter pub get

# ── Checks ──────────────────────────────────────────────────────────────────
# GitHub Actions was removed for billing, so nothing else runs these. Rather
# than needing a second CI service — or anyone installing Flutter locally —
# they run here, in the build that already has the SDK. Costs nothing extra:
# this container is being spun up regardless.
#
# The results appear in the Vercel build log, readable after the fact without
# any local setup.

echo "==========================================================="
echo "  flutter test"
echo "==========================================================="
# Runs BEFORE analyze so its result is never buried: Vercel truncates the log
# at 4 MB and a noisy analyze pass previously swallowed it entirely.
#
# The suite has never been confirmed green, so a failure must not block
# deployment yet — an untested assertion breaking a release would be worse
# than the bug it was meant to catch. Once a build shows it passing, drop the
# '|| echo' and it becomes a real gate.
flutter test --reporter compact \
  || echo ">>> TESTS FAILED - not blocking yet, see note in vercel-build.sh"

echo
echo "==========================================================="
echo "  flutter analyze"
echo "==========================================================="
# Non-blocking. `flutter build` below already fails the deploy on a genuine
# compile or type error, so the value here is the lint and warning output,
# which should not block a deploy on its own.
# Scope to OUR code. The Flutter SDK is cloned into _flutter_sdk inside the
# project, so a bare `flutter analyze` walks the SDK's own packages too — its
# integration_test package alone emits thousands of errors against this SDK
# version. That flooded the build log past Vercel's 4 MB limit and buried the
# test results, which is the whole reason these steps exist.
flutter analyze lib test 2>&1 | tail -40 \
  || echo ">>> analyze reported issues (not blocking the deploy)"

echo
echo "==========================================================="
echo "  flutter build web"
echo "==========================================================="
# This one IS blocking (set -e). A compile or type error fails the deploy, so
# broken code cannot reach production even with the checks above soft.
flutter build web --release --no-tree-shake-icons
