"""File operation benchmarks."""

import sys
import time
import os
import tempfile
import shutil
from pathlib import Path
from typing import Dict

# Add utils to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.timing import Timer


def benchmark_fileops(driver_class, iterations: int = 5) -> Dict:
    """Benchmark file operations (save/load)."""
    results = {}

    # Save file operations
    def test_save(filesize_name: str):
        temp_dir = tempfile.mkdtemp()
        temp_file = os.path.join(temp_dir, "test.txt")

        try:
            # Copy test file
            src = f"benchmark/fixtures/{filesize_name}.txt"
            if os.path.exists(src):
                shutil.copy(src, temp_file)

                driver = driver_class()
                try:
                    driver.start(temp_file)
                    driver.send_keys("i", delay=0.001)
                    driver.send_keys("test content", delay=0.001)
                    driver.send_keys("<ESC>", delay=0.01)

                    # Measure save operation
                    save_start = time.perf_counter()
                    driver.send_keys(":w<CR>", delay=0.02)
                    time.sleep(0.2)  # Wait for save to complete
                    save_time = time.perf_counter() - save_start

                    driver.quit(force=True)
                    return save_time
                finally:
                    time.sleep(0.1)
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)

    # Load file operations
    def test_load(filesize_name: str):
        driver = driver_class()
        try:
            load_start = time.perf_counter()
            driver.start(f"benchmark/fixtures/{filesize_name}.txt")
            load_time = time.perf_counter() - load_start
            driver.quit(force=True)
            return load_time
        finally:
            time.sleep(0.1)

    test_sizes = ["small_100", "medium_1k", "large_10k"]

    # Load benchmarks
    for size in test_sizes:
        if os.path.exists(f"benchmark/fixtures/{size}.txt"):
            timer = Timer()
            for _ in range(iterations):
                load_time = test_load(size)
                timer.times.append(load_time)
            results[f"load_{size}"] = timer.get_stats()

    # Save benchmarks (slower, fewer iterations)
    save_iterations = min(3, iterations)
    for size in test_sizes:
        if os.path.exists(f"benchmark/fixtures/{size}.txt"):
            timer = Timer()
            for _ in range(save_iterations):
                save_time = test_save(size)
                if save_time:
                    timer.times.append(save_time)
            if timer.times:
                results[f"save_{size}"] = timer.get_stats()

    return results
