#!/usr/bin/env python3
"""Fuzzing test runner for stress testing editors."""

import argparse
import sys
from pathlib import Path

# Add current directory to path for imports
benchmark_dir = Path(__file__).parent
sys.path.insert(0, str(benchmark_dir))

from drivers.vite_driver import ViteDriver
from drivers.nvim_driver import NvimDriver
from utils.fuzzer import InputFuzzer, FuzzRunner, FuzzConfig
from utils.debug import setup_debug_logging
from utils.recovery import RecoveryManager, GracefulShutdown


def run_fuzz_benchmark(editor: str, iterations: int = 100, verbose: bool = False, file_path: str | None = None):
    """Run fuzzing benchmarks for a specific editor."""

    # Setup debug logging
    logger = setup_debug_logging(verbose=verbose)

    # Setup recovery and graceful shutdown
    recovery_manager = RecoveryManager(logger)
    graceful_shutdown = GracefulShutdown(logger)
    graceful_shutdown.register_cleanup(recovery_manager.cleanup_failed_processes)

    # Select driver
    if editor == "vite":
        driver_class = ViteDriver
    elif editor == "nvim":
        driver_class = NvimDriver
    else:
        print(f"Unknown editor: {editor}")
        return 1

    logger.info(f"Starting fuzzing benchmark for {editor}", {"iterations": iterations})

    try:
        # Create fuzz runner
        fuzz_runner = FuzzRunner(driver_class, debug=verbose)

        # Configure fuzzing
        config = FuzzConfig(
            max_sequence_length=150,
            min_sequence_length=10,
            include_special_keys=True,
            include_unicode=True,
            seed=42,  # For reproducible results
        )

        # Run fuzzing suite
        logger.info("Running main fuzzing suite")
        results = fuzz_runner.run_fuzz_suite(iterations, config, file_path=file_path)

        # Get summary
        summary = fuzz_runner.get_summary()
        
        if "fuzz_results" not in summary:
            logger.error("No fuzzing results generated")
            return 1
            
        fuzz_stats = summary["fuzz_results"]

        # Print results
        print(f"\n{'=' * 60}")
        print(f"FUZZING RESULTS FOR {editor.upper()}")
        print(f"{'=' * 60}")
        print(f"Total sequences: {fuzz_stats['total_sequences']}")
        print(f"Successful: {fuzz_stats['successful']}")
        print(f"Failed: {fuzz_stats['failed']}")
        print(f"Success rate: {fuzz_stats['success_rate']:.2%}")
        print(f"Average execution time: {fuzz_stats['average_execution_time']:.3f}s")

        if fuzz_stats["error_distribution"]:
            print(f"\nError distribution:")
            for error, count in fuzz_stats["error_distribution"].items():
                print(f"  {error}: {count}")

        # Save detailed results
        results_file = f"logs/fuzz_results_{editor}_{iterations}.json"
        Path("logs").mkdir(exist_ok=True)
        import json

        with open(results_file, "w") as f:
            json.dump(summary, f, indent=2, default=str)
        print(f"\nDetailed results saved to: {results_file}")

        logger.info("Fuzzing benchmark completed", summary)

        return (
            0 if fuzz_stats["success_rate"] > 0.8 else 1
        )  # Consider <80% success as failure

    except KeyboardInterrupt:
        logger.info("Fuzzing interrupted by user")
        return 1
    except Exception as e:
        logger.error(f"Fuzzing failed: {str(e)}", exc_info=True)
        return 1


def run_stress_tests(editor: str, verbose: bool = False):
    """Run stress test scenarios."""

    logger = setup_debug_logging(verbose=verbose)

    # Select driver
    if editor == "vite":
        driver_class = ViteDriver
    elif editor == "nvim":
        driver_class = NvimDriver
    else:
        print(f"Unknown editor: {editor}")
        return 1

    logger.info(f"Running stress test scenarios for {editor}")

    try:
        fuzz_runner = FuzzRunner(driver_class, debug=verbose)
        results = fuzz_runner.run_stress_suite()

        # Summary
        successful = sum(1 for r in results if r.success)
        success_rate = successful / len(results)

        print(f"\nStress Test Summary:")
        print(f"Total: {len(results)}")
        print(f"Successful: {successful}")
        print(f"Failed: {len(results) - successful}")
        print(f"Success rate: {success_rate:.2%}")

        # Save results
        import json

        results_data = {
            "stress_tests": len(results),
            "successful": successful,
            "failed": len(results) - successful,
            "success_rate": success_rate,
            "detailed_results": [
                {
                    "sequence": r.sequence,
                    "success": r.success,
                    "error": r.error,
                    "execution_time": r.execution_time,
                }
                for r in results
            ],
        }

        results_file = f"logs/stress_tests_{editor}.json"
        Path("logs").mkdir(exist_ok=True)
        with open(results_file, "w") as f:
            json.dump(results_data, f, indent=2, default=str)
        print(f"Detailed results saved to: {results_file}")

        return (
            0 if success_rate > 0.5 else 1
        )  # Stress tests are expected to fail sometimes

    except Exception as e:
        logger.error(f"Stress testing failed: {str(e)}", exc_info=True)
        return 1


def run_behavior_tests(editor: str, verbose: bool = False):
    """Run behavior tests to detect non-standard behavior."""

    logger = setup_debug_logging(verbose=verbose)

    # Select driver
    if editor == "vite":
        driver_class = ViteDriver
    elif editor == "nvim":
        driver_class = NvimDriver
    else:
        print(f"Unknown editor: {editor}")
        return 1

    logger.info(f"Running behavior tests for {editor}")

    try:
        fuzz_runner = FuzzRunner(driver_class, debug=verbose)

        # Run behavior suite (tests for non-standard behavior like Ctrl+C exit)
        behavior_results = fuzz_runner.run_behavior_suite()

        # Also run non-standard sequence detection
        fuzz_runner.run_non_standard_detection()

        # Get combined summary
        summary = fuzz_runner.get_summary()

        # Save results
        import json

        results_file = f"logs/behavior_tests_{editor}.json"
        Path("logs").mkdir(exist_ok=True)
        with open(results_file, "w") as f:
            json.dump(summary, f, indent=2, default=str)
        print(f"\nDetailed results saved to: {results_file}")

        # Return success only if all behavior tests pass
        if "behavior_results" in summary:
            return 0 if summary["behavior_results"]["pass_rate"] == 1.0 else 1
        return 1

    except Exception as e:
        logger.error(f"Behavior testing failed: {str(e)}", exc_info=True)
        return 1


def run_edge_cases(editor: str, verbose: bool = False):
    """Run edge case scenarios."""

    logger = setup_debug_logging(verbose=verbose)

    # Select driver
    if editor == "vite":
        driver_class = ViteDriver
    elif editor == "nvim":
        driver_class = NvimDriver
    else:
        print(f"Unknown editor: {editor}")
        return 1

    logger.info(f"Running edge case scenarios for {editor}")

    try:
        fuzz_runner = FuzzRunner(driver_class, debug=verbose)
        fuzzer = InputFuzzer()

        # Get edge case sequences
        edge_cases = fuzzer.generate_edge_case_sequences()

        print(f"\n{'=' * 60}")
        print(f"EDGE CASE TESTING FOR {editor.upper()}")
        print(f"{'=' * 60}")
        print(f"Running {len(edge_cases)} edge case scenarios...")

        results = []
        for i, sequence in enumerate(edge_cases, 1):
            print(
                f"\nTest {i}/{len(edge_cases)}: {repr(sequence[:30])}{'...' if len(sequence) > 30 else ''}"
            )

            result = fuzz_runner.run_sequence(sequence)
            results.append(result)

            status = "✓ PASS" if result.success else "✗ FAIL"
            print(f"  {status} ({result.execution_time:.3f}s)")

            if not result.success and verbose:
                print(f"  Error: {result.error}")

        # Summary
        successful = sum(1 for r in results if r.success)
        success_rate = successful / len(results)

        print(f"\nEdge Case Summary:")
        print(f"Total: {len(results)}")
        print(f"Successful: {successful}")
        print(f"Failed: {len(results) - successful}")
        print(f"Success rate: {success_rate:.2%}")

        # Save results
        import json

        results_data = {
            "edge_cases": len(edge_cases),
            "successful": successful,
            "failed": len(results) - successful,
            "success_rate": success_rate,
            "detailed_results": [
                {
                    "sequence": r.sequence,
                    "success": r.success,
                    "error": r.error,
                    "execution_time": r.execution_time,
                }
                for r in results
            ],
        }

        results_file = f"logs/edge_cases_{editor}.json"
        Path("logs").mkdir(exist_ok=True)
        with open(results_file, "w") as f:
            json.dump(results_data, f, indent=2, default=str)
        print(f"Detailed results saved to: {results_file}")

        return (
            0 if success_rate > 0.5 else 1
        )  # Edge cases are expected to fail sometimes

    except Exception as e:
        logger.error(f"Edge case testing failed: {str(e)}", exc_info=True)
        return 1


def main():
    parser = argparse.ArgumentParser(description="Fuzz and stress test editors")
    parser.add_argument("editor", choices=["vite", "nvim"], help="Editor to test")
    parser.add_argument(
        "-i",
        "--iterations",
        type=int,
        default=100,
        help="Number of fuzzing iterations (default: 100)",
    )
    parser.add_argument(
        "-e",
        "--edge-cases",
        action="store_true",
        help="Run edge case scenarios instead of random fuzzing",
    )
    parser.add_argument(
        "-s", "--stress", action="store_true", help="Run stress test scenarios"
    )
    parser.add_argument(
        "-b", "--behavior", action="store_true", help="Run behavior tests (detect non-standard behavior)"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose debug output"
    )
    parser.add_argument(
        "-f", "--file", help="File to open in the editor"
    )

    args = parser.parse_args()

    if args.behavior:
        return run_behavior_tests(args.editor, args.verbose)
    elif args.stress:
        return run_stress_tests(args.editor, args.verbose)
    elif args.edge_cases:
        return run_edge_cases(args.editor, args.verbose)
    else:
        return run_fuzz_benchmark(args.editor, args.iterations, args.verbose, args.file)


if __name__ == "__main__":
    sys.exit(main())
