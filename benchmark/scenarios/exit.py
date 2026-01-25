"""Exit/quit time benchmarks."""

import sys
import time
import os
from pathlib import Path
from typing import Dict

# Add utils to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.timing import Timer


def benchmark_exit(driver_class, iterations: int = 5) -> Dict:
    """Benchmark exit time with various file sizes."""
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
                driver.start(filepath)
                # Small delay to ensure editor is fully settled
                time.sleep(0.1)

                # Time the exit operation specifically
                exit_time = driver.quit(force=True)
                timer.times.append(exit_time)
            except Exception:
                # Ensure cleanup on error
                try:
                    driver.cleanup()
                except Exception:
                    pass
            finally:
                time.sleep(0.1)

        if timer.times:
            results[name] = timer.get_stats()

    return results
