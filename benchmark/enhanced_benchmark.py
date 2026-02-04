#!/usr/bin/env python3
"""Enhanced benchmark runner with fuzzing and debugging."""

import sys
from pathlib import Path

# Add current directory to path for imports
benchmark_dir = Path(__file__).parent
sys.path.insert(0, str(benchmark_dir))
project_root = benchmark_dir.parent
log_dir = project_root / "logs"

from utils.integration import create_enhanced_benchmark_runner


def main():
    """Run enhanced benchmark suite with fuzzing and debugging."""
    print("Enhanced Benchmark Runner with Fuzzing and Debugging")
    print("=" * 60)

    # Create enhanced runner
    runner = create_enhanced_benchmark_runner(verbose=True, enable_fuzzing=True, log_dir=log_dir)

    try:
        # Run full suite
        results = runner.run_full_suite(benchmark_iterations=3, fuzz_iterations=25)

        # Print summary
        runner.print_summary()

        print(f"\nEnhanced benchmark completed successfully!")
        return 0

    except KeyboardInterrupt:
        print("\nBenchmark interrupted by user")
        return 1
    except Exception as e:
        print(f"Benchmark failed: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
