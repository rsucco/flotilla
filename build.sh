#!/usr/bin/env bash
# Exports every platform into builds/. Needs Godot 4 as `godot` and its
# matching export templates (Editor > Manage Export Templates).
set -eu

cd "$(dirname "$0")"
mkdir -p builds/web

godot --headless --export-release "Linux" builds/Flotilla_Linux.x86_64
godot --headless --export-release "Windows Desktop" builds/Flotilla_Windows.exe
godot --headless --export-release "macOS" builds/Flotilla_macOS.zip
godot --headless --export-release "Web" builds/web/index.html
