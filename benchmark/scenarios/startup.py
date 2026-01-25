"""Startup time benchmarks."""

import sys
import time
import os
from pathlib import Path
from typing import Dict

# Add utils to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.timing import Timer


def benchmark_startup(driver_class, iterations: int = 5) -> Dict:
    """Benchmark startup time with various file sizes."""
    results = {}

    test_files = {
        "empty": "benchmark/fixtures/empty.txt",
        "100_lines": "benchmark/fixtures/small_100.txt",
        "1k_lines": "benchmark/fixtures/medium_1k.txt",
        "10k_lines": "benchmark/fixtures/large_10k.txt",
    }

    for name, filepath in test_files.items():
        if not os.path.exists(filepath):
            continue

        timer = Timer()

        for _ in range(iterations):
            driver = driver_class()
            try:
                startup_time = driver.start(filepath)
                timer.times.append(startup_time)
            finally:
                driver.quit(force=True)
                time.sleep(0.1)

        results[name] = timer.get_stats()

    return results
