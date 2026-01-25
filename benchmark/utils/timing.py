"""Timing utilities for benchmarking."""

import time
from typing import Callable, Tuple
from statistics import mean, median, stdev


class Timer:
    """High-resolution timer using perf_counter."""

    def __init__(self):
        self.start_time = None
        self.times = []

    def __enter__(self):
        self.start_time = time.perf_counter()
        return self

    def __exit__(self, *args):
        end_time = time.perf_counter()
        elapsed = end_time - self.start_time
        self.times.append(elapsed)

    def start(self):
        """Start timing."""
        self.start_time = time.perf_counter()

    def stop(self) -> float:
        """Stop timing and return elapsed time."""
        end_time = time.perf_counter()
        elapsed = end_time - self.start_time
        self.times.append(elapsed)
        return elapsed

    def reset(self):
        """Clear recorded times."""
        self.times = []

    def get_stats(self) -> dict:
        """Get statistics from recorded times."""
        if not self.times:
            return {}

        times = self.times
        return {
            "mean": mean(times),
            "median": median(times),
            "stddev": stdev(times) if len(times) > 1 else 0,
            "min": min(times),
            "max": max(times),
            "count": len(times),
        }


def time_function(func: Callable, iterations: int = 5) -> dict:
    """Time a function over multiple iterations."""
    timer = Timer()
    timer.reset()

    for _ in range(iterations):
        with timer:
            func()

    return timer.get_stats()
