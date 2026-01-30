"""Integration with existing benchmark system for fuzzing and debugging."""

from typing import Dict, Any
from .fuzzer import FuzzRunner, FuzzConfig
from .debug import DebugLogger, ErrorTracker
from .recovery import RecoveryManager, HealthChecker


def add_fuzzing_to_benchmark(benchmark_runner):
    """Add fuzzing capabilities to existing benchmark runner."""

    def run_fuzzing(
        self, iterations: int = 50, editor: str = "all", verbose: bool = False
    ):
        """Extended fuzzing method for benchmark runner."""

        # Setup debug logging
        logger = DebugLogger(verbose=verbose)

        # Setup recovery
        recovery = RecoveryManager(logger)
        health_checker = HealthChecker(logger)

        # Check editor health
        if editor == "all":
            editors_to_test = ["vite", "nvim"]
        else:
            editors_to_test = [editor]

        fuzz_results = {}

        for editor_name in editors_to_test:
            logger.info(f"Starting fuzzing for {editor_name}")

            if not health_checker.check_editor_health(editor_name):
                logger.error(f"Editor {editor_name} failed health check, skipping")
                continue

            # Get driver class
            if editor == "vite":
                from ..drivers.vite_driver import ViteDriver

                driver_class = ViteDriver
            elif editor == "nvim":
                from ..drivers.nvim_driver import NvimDriver

                driver_class = NvimDriver
            else:
                logger.warning(f"Unknown editor: {editor_name}")
                continue

            # Run fuzzing with recovery
            def run_fuzz():
                fuzz_runner = FuzzRunner(driver_class, debug=verbose)
                config = FuzzConfig(
                    max_sequence_length=100,
                    include_special_keys=True,
                    include_unicode=True,
                )
                return fuzz_runner.run_fuzz_suite(iterations, config)

            try:
                results = recovery.retry_operation(
                    run_fuzz, f"fuzz_{editor_name}", {"iterations": iterations}
                )

                fuzz_runner = FuzzRunner(driver_class, debug=verbose)
                fuzz_runner.results = results
                fuzz_results[editor_name] = fuzz_runner.get_summary()

                logger.info(f"Fuzzing completed for {editor_name}")

            except Exception as e:
                logger.error(f"Fuzzing failed for {editor_name}: {str(e)}")
                fuzz_results[editor_name] = {
                    "error": str(e),
                    "total_sequences": 0,
                    "successful": 0,
                    "failed": 0,
                    "success_rate": 0,
                }

        return fuzz_results

    # Add method to benchmark runner
    import types

    benchmark_runner.run_fuzzing = types.MethodType(run_fuzzing, benchmark_runner)

    return benchmark_runner


def create_enhanced_benchmark_runner(
    verbose: bool = False, enable_fuzzing: bool = True
):
    """Create an enhanced benchmark runner with fuzzing and debugging."""

    class EnhancedBenchmarkRunner:
        """Benchmark runner with integrated fuzzing and debugging."""

        def __init__(self):
            self.verbose = verbose
            self.enable_fuzzing = enable_fuzzing
            self.logger = DebugLogger(verbose=verbose)
            self.error_tracker = ErrorTracker(self.logger)
            self.recovery_manager = RecoveryManager(self.logger)
            self.health_checker = HealthChecker(self.logger)
            self.enable_fuzzing = enable_fuzzing

            # Store results
            self.benchmark_results = {}
            self.fuzz_results = {}

        def run_standard_benchmarks(self, iterations: int = 5):
            """Run standard benchmark suite."""
            from ..benchmark import run_benchmarks

            try:
                self.logger.info("Starting standard benchmark suite")
                results = self.recovery_manager.retry_operation(
                    lambda: run_benchmarks(iterations),
                    "standard_benchmarks",
                    {"iterations": iterations},
                )
                self.benchmark_results = results
                return results

            except Exception as e:
                self.error_tracker.record_error(e, {"operation": "standard_benchmarks"})
                raise

        def run_fuzzing_benchmarks(
            self, iterations: int = 50, editors: list | None = None
        ):
            """Run fuzzing benchmarks."""
            if not self.enable_fuzzing:
                self.logger.warning("Fuzzing is disabled")
                return {}

            if editors is None:
                editors = ["vite", "nvim"]

            from .fuzzer import FuzzRunner, FuzzConfig

            for editor in editors:
                if not self.health_checker.check_editor_health(editor):
                    self.logger.warning(f"Skipping {editor} due to failed health check")
                    continue

                try:
                    self.logger.info(f"Running fuzzing for {editor}")

                    # Get driver class
                    driver_class = None
                    if editor == "vite":
                        from ..drivers.vite_driver import ViteDriver

                        driver_class = ViteDriver
                    elif editor == "nvim":
                        from ..drivers.nvim_driver import NvimDriver

                        driver_class = NvimDriver

                    fuzz_runner = FuzzRunner(driver_class, debug=self.logger.verbose)
                    config = FuzzConfig(
                        max_sequence_length=100,
                        include_special_keys=True,
                        include_unicode=True,
                    )

                    results = self.recovery_manager.retry_operation(
                        lambda: fuzz_runner.run_fuzz_suite(iterations, config),
                        f"fuzz_{editor}",
                        {"iterations": iterations},
                    )

                    fuzz_runner.results = results
                    self.fuzz_results[editor] = fuzz_runner.get_summary()

                except Exception as e:
                    self.error_tracker.record_error(
                        e, {"editor": editor, "operation": "fuzzing"}
                    )
                    self.fuzz_results[editor] = {"error": str(e)}

        def run_full_suite(
            self, benchmark_iterations: int = 5, fuzz_iterations: int = 50
        ):
            """Run complete benchmark and fuzzing suite."""
            self.logger.info("Starting full benchmark and fuzzing suite")

            # Check system health first
            health = self.health_checker.check_system_resources()
            if not health["healthy"]:
                self.logger.warning(
                    "System resources may be insufficient for full suite"
                )

            # Run standard benchmarks
            self.run_standard_benchmarks(benchmark_iterations)

            # Run fuzzing
            self.run_fuzzing_benchmarks(fuzz_iterations)

            # Generate combined report
            return self.generate_combined_report()

        def generate_combined_report(self) -> Dict[str, Any]:
            """Generate a combined report of all results."""
            report = {
                "timestamp": self.logger.events[0].timestamp
                if self.logger.events
                else None,
                "benchmark_results": self.benchmark_results,
                "fuzz_results": self.fuzz_results,
                "error_summary": self.error_tracker.get_error_patterns(),
                "system_health": self.health_checker.check_system_resources(),
            }

            # Save report
            import json
            from pathlib import Path
            from datetime import datetime

            Path("logs").mkdir(exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            report_file = f"logs/enhanced_report_{timestamp}.json"

            with open(report_file, "w") as f:
                json.dump(report, f, indent=2, default=str)

            self.logger.info(f"Combined report saved to {report_file}")

            return report

        def print_summary(self):
            """Print a summary of all results."""
            print(f"\n{'=' * 80}")
            print("ENHANCED BENCHMARK AND FUZZING SUMMARY")
            print(f"{'=' * 80}")

            if self.benchmark_results:
                print("\nStandard Benchmarks:")
                for category, results in self.benchmark_results.items():
                    if isinstance(results, dict):
                        for editor, times in results.items():
                            if times and len(times) > 0:
                                avg_time = sum(times) / len(times)
                                print(f"  {category}/{editor}: {avg_time:.3f}s avg")

            if self.fuzz_results:
                print("\nFuzzing Results:")
                for editor, results in self.fuzz_results.items():
                    if "error" in results:
                        print(f"  {editor}: FAILED - {results['error']}")
                    else:
                        success_rate = results.get("success_rate", 0)
                        total = results.get("total_sequences", 0)
                        print(
                            f"  {editor}: {success_rate:.1%} success ({total} sequences)"
                        )

            error_patterns = self.error_tracker.get_error_patterns()
            if error_patterns:
                print(f"\nError Patterns:")
                for error_type, count in error_patterns.items():
                    print(f"  {error_type}: {count}")

    return EnhancedBenchmarkRunner()
