#!/usr/bin/env python3
"""Main benchmark runner for vite vs nvim comparison."""

import sys
import os
import time
import argparse
import subprocess
from pathlib import Path

# Add current directory to path for imports
benchmark_dir = Path(__file__).parent
sys.path.insert(0, str(benchmark_dir))

from drivers.vite_driver import ViteDriver
from drivers.nvim_driver import NvimDriver
from scenarios import startup, insertion, movement, fileops
from utils.test_data import generate_test_files, cleanup_test_files
from utils.reporting import Reporter


def get_version(editor_name: str, driver_class) -> str:
    """Get version string for an editor."""
    try:
        if editor_name == "vite":
            # vite doesn't have a --version flag, get from git or package
            result = subprocess.run(
                ["git", "describe", "--tags", "--always"],
                cwd=os.path.dirname(__file__),
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0:
                return result.stdout.strip()
            return "unknown"
        elif editor_name == "nvim":
            result = subprocess.run(
                ["nvim", "--version"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            if result.returncode == 0:
                # Extract first line which contains version
                return result.stdout.split("\n")[0]
            return "unknown"
    except Exception:
        return "unknown"


def run_benchmarks(iterations: int = 5, skip_nvim: bool = False) -> dict:
    """Run all benchmark suites."""
    print("Generating test files...")
    test_files = generate_test_files()
    print(f"  Created {len(test_files)} test files")

    results = {}
    metadata = {}

    # Test vite
    print("\n" + "=" * 80)
    print("BENCHMARKING vite")
    print("=" * 80)

    try:
        vite_version = get_version("vite", ViteDriver)
        metadata["vite_version"] = vite_version
        print(f"vite version: {vite_version}")

        print("\nRunning startup benchmarks...")
        results["startup"] = {}
        vite_startup = startup.benchmark_startup(ViteDriver, iterations)
        results["startup"]["vite"] = vite_startup
        print("  ✓ Startup benchmarks complete")

        print("Running insertion benchmarks...")
        results["insertion"] = {}
        vite_insertion = insertion.benchmark_insertion(ViteDriver, iterations)
        results["insertion"]["vite"] = vite_insertion
        print("  ✓ Insertion benchmarks complete")

        print("Running movement benchmarks...")
        results["movement"] = {}
        vite_movement = movement.benchmark_movement(ViteDriver, iterations)
        results["movement"]["vite"] = vite_movement
        print("  ✓ Movement benchmarks complete")

        print("Running file operation benchmarks...")
        results["fileops"] = {}
        vite_fileops = fileops.benchmark_fileops(ViteDriver, iterations)
        results["fileops"]["vite"] = vite_fileops
        print("  ✓ File operation benchmarks complete")

    except Exception as e:
        print(f"✗ Error benchmarking vite: {e}", file=sys.stderr)
        import traceback

        traceback.print_exc()

    # Test nvim
    if not skip_nvim:
        print("\n" + "=" * 80)
        print("BENCHMARKING Neovim")
        print("=" * 80)

        try:
            nvim_version = get_version("nvim", NvimDriver)
            metadata["nvim_version"] = nvim_version
            print(f"nvim version: {nvim_version}")

            print("\nRunning startup benchmarks...")
            nvim_startup = startup.benchmark_startup(NvimDriver, iterations)
            results["startup"]["nvim"] = nvim_startup
            print("  ✓ Startup benchmarks complete")

            print("Running insertion benchmarks...")
            nvim_insertion = insertion.benchmark_insertion(NvimDriver, iterations)
            results["insertion"]["nvim"] = nvim_insertion
            print("  ✓ Insertion benchmarks complete")

            print("Running movement benchmarks...")
            nvim_movement = movement.benchmark_movement(NvimDriver, iterations)
            results["movement"]["nvim"] = nvim_movement
            print("  ✓ Movement benchmarks complete")

            print("Running file operation benchmarks...")
            nvim_fileops = fileops.benchmark_fileops(NvimDriver, iterations)
            results["fileops"]["nvim"] = nvim_fileops
            print("  ✓ File operation benchmarks complete")

        except Exception as e:
            print(f"✗ Error benchmarking nvim: {e}", file=sys.stderr)
            if "not found" not in str(e).lower():
                import traceback

                traceback.print_exc()

    # Generate reports
    print("\n" + "=" * 80)
    print("GENERATING REPORTS")
    print("=" * 80)

    reporter = Reporter()

    json_path = reporter.save_json(results, metadata)
    print(f"✓ JSON results saved to: {json_path}")

    md_path = reporter.save_markdown(results, metadata)
    print(f"✓ Markdown results saved to: {md_path}")

    reporter.print_summary(results, metadata)

    # Cleanup
    print("Cleaning up test files...")
    cleanup_test_files()

    return results


def main():
    parser = argparse.ArgumentParser(description="Benchmark vite vs Neovim")
    parser.add_argument(
        "-i",
        "--iterations",
        type=int,
        default=5,
        help="Number of iterations per benchmark (default: 5)",
    )
    parser.add_argument(
        "--skip-nvim",
        action="store_true",
        help="Skip Neovim benchmarks (only test vite)",
    )

    args = parser.parse_args()

    try:
        results = run_benchmarks(iterations=args.iterations, skip_nvim=args.skip_nvim)
        sys.exit(0)
    except KeyboardInterrupt:
        print("\n\nBenchmark interrupted by user", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Benchmark failed: {e}", file=sys.stderr)
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
