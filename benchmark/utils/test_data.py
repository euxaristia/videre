"""Test data generator for benchmarks."""

import os
from pathlib import Path


def generate_file(path: str, num_lines: int) -> str:
    """Generate a test file with specified number of lines."""
    os.makedirs(os.path.dirname(path), exist_ok=True)

    with open(path, "w") as f:
        for i in range(num_lines):
            f.write(f"Line {i + 1}: The quick brown fox jumps over the lazy dog.\n")

    return path


def generate_test_files(base_dir: str = "benchmark/fixtures") -> dict:
    """Generate all test files needed for benchmarks."""
    os.makedirs(base_dir, exist_ok=True)

    files = {
        "empty": os.path.join(base_dir, "empty.txt"),
        "small_100": os.path.join(base_dir, "small_100.txt"),
        "medium_1k": os.path.join(base_dir, "medium_1k.txt"),
        "large_10k": os.path.join(base_dir, "large_10k.txt"),
        "huge_100k": os.path.join(base_dir, "huge_100k.txt"),
    }

    # Generate files
    generate_file(files["empty"], 0)
    generate_file(files["small_100"], 100)
    generate_file(files["medium_1k"], 1000)
    generate_file(files["large_10k"], 10000)
    generate_file(files["huge_100k"], 100000)

    return files


def cleanup_test_files(base_dir: str = "benchmark/fixtures"):
    """Clean up generated test files."""
    if os.path.exists(base_dir):
        import shutil

        shutil.rmtree(base_dir)
