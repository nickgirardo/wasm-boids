#!/bin/sh

# Using a simple build script instead of a more robust build system
# because this project is so small and simple.

# Clean previous build products if any exist
[ -d build ] && rm -r build

mkdir build

# Compile
wat2wasm flock.wat -o build/flock.wasm

# Optimization pass
# Using -O4 because my wat was handwritten
wasm-opt build/flock.wasm -O4 -o build/flock.wasm

# Copy over other resources
cp index.html build/
cp app.js build/
cp style.css build/
