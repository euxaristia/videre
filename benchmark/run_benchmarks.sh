#!/bin/bash
# Convenience script to run benchmarks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Building videre in release mode..."
cd "$PROJECT_ROOT"
swift build -c release > /dev/null 2>&1

echo "Running benchmark suite..."
cd "$SCRIPT_DIR"
python3 benchmark.py "$@"

echo "Done!"
