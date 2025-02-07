#!/usr/bin/env bash
# Requires `godot3-bin` to be on your path, can be easily installed with the godot3-bin AUR package

godot3-bin --export "Linux/X11" ./builds/Flotilla_Linux.x86_64	
godot3-bin --export "Windows Desktop" ./builds/Flotilla_Windows.exe
godot3-bin --export "Mac OSX" ./builds/Flotilla_macOS.zip

