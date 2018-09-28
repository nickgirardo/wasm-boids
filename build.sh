#!/bin/sh

# Using a simple build script instead of a more robust build system
# because this project is so small and simple.

# Compile
wat2wasm flock.wat -o flock.wasm

# Optimization pass
# Using -O4 because my wat was handwritten
wasm-opt flock.wasm -O4 -o flock.wasm
