"""Cursor movement benchmarks."""

import sys
import time
import os
from pathlib import Path
from typing import Dict

# Add utils to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.timing import Timer


def benchmark_movement(driver_class, iterations: int = 5) -> Dict:
    """Benchmark cursor movement operations."""
    results = {}

    # hjkl movement (1000 times total)
    def test_hjkl():
        driver = driver_class()
        try:
            driver.start("benchmark/fixtures/medium_1k.txt")
            # Mix of movements: h (left), j (down), k (up), l (right)
            for _ in range(250):
                driver.send_keys("hjkl", delay=0.001)
        finally:
            driver.quit(force=True)
            time.sleep(0.1)

    # Word motions w/b/e (500 times)
    def test_word_motion():
        driver = driver_class()
        try:
            driver.start("benchmark/fixtures/medium_1k.txt")
            for _ in range(250):
                driver.send_keys("wbe", delay=0.001)
        finally:
            driver.quit(force=True)
            time.sleep(0.1)

    # Line motions 0/$
    def test_line_motion():
        driver = driver_class()
        try:
            driver.start("benchmark/fixtures/medium_1k.txt")
            for _ in range(250):
                driver.send_keys("0", delay=0.002)
                driver.send_keys("$", delay=0.002)
        finally:
            driver.quit(force=True)
            time.sleep(0.1)

    # Jumps gg/G
    def test_jumps():
        driver = driver_class()
        try:
            driver.start("benchmark/fixtures/medium_1k.txt")
            for _ in range(50):
                driver.send_keys("gg", delay=0.005)
                driver.send_keys("G", delay=0.005)
        finally:
            driver.quit(force=True)
            time.sleep(0.1)

    tests = {
        "hjkl_1000": test_hjkl,
        "word_motion_500": test_word_motion,
        "line_motion_500": test_line_motion,
        "jumps_100": test_jumps,
    }

    for name, test_func in tests.items():
        timer = Timer()

        for _ in range(iterations):
            test_start = time.perf_counter()
            test_func()
            test_end = time.perf_counter()
            timer.times.append(test_end - test_start)

        results[name] = timer.get_stats()

    return results
