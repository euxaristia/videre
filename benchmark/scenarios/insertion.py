"""Text insertion benchmarks."""

import sys
import time
from pathlib import Path
from typing import Dict

# Add utils to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))
from utils.timing import Timer


def benchmark_insertion(driver_class, iterations: int = 5) -> Dict:
    """Benchmark text insertion operations."""
    results = {}

    # Single character insertion (100 times)
    def test_single_char():
        driver = driver_class()
        try:
            driver.start()
            driver.send_keys("i")  # Enter insert mode
            for i in range(100):
                driver.send_keys("a", delay=0.001)
            driver.send_keys("<ESC>")
        finally:
            driver.quit(force=True)
            time.sleep(0.1)

    # Word insertion (50 times)
    def test_word():
        driver = driver_class()
        try:
            driver.start()
            driver.send_keys("i")
            for i in range(50):
                driver.send_keys("word ", delay=0.001)
            driver.send_keys("<ESC>")
        finally:
            driver.quit(force=True)
            time.sleep(0.1)

    # Line insertion (20 times)
    def test_line():
        driver = driver_class()
        try:
            driver.start()
            for i in range(20):
                driver.send_keys("iThis is a line of text<CR>", delay=0.001)
            driver.send_keys("<ESC>")
        finally:
            driver.quit(force=True)
            time.sleep(0.1)

    tests = {
        "single_chars_100": test_single_char,
        "words_50": test_word,
        "lines_20": test_line,
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
