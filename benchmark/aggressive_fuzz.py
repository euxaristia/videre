#!/usr/bin/env python3
"""Aggressive fuzzing to find edge cases and crashes."""

import sys
from pathlib import Path

# Add current directory to path for imports
benchmark_dir = Path(__file__).parent
sys.path.insert(0, str(benchmark_dir))

from drivers.videre_driver import VidereDriver
from drivers.nvim_driver import NvimDriver
from utils.fuzzer import FuzzRunner, FuzzConfig, InputFuzzer
from utils.debug import setup_debug_logging


def run_aggressive_fuzz(editor: str, iterations: int = 50, file_path: str | None = None):
    """Run aggressive fuzzing to find crashes."""

    logger = setup_debug_logging(verbose=True)

    # Select driver
    if editor == "videre":
        driver_class = VidereDriver
    elif editor == "nvim":
        driver_class = NvimDriver
    else:
        print(f"Unknown editor: {editor}")
        return 1

    logger.info(f"Starting aggressive fuzzing for {editor}")

    # Configure aggressive fuzzing
    config = FuzzConfig(
        max_sequence_length=300,  # Longer sequences
        min_sequence_length=1,  # Include very short sequences
        include_special_keys=True,
        include_unicode=True,
        seed=None,  # Random seed for maximum coverage
    )

    fuzz_runner = FuzzRunner(driver_class, debug=True)

    # Run multiple rounds with different strategies
    strategies = [
        ("Random Fuzzing", lambda: fuzz_runner.run_fuzz_suite(iterations, config, file_path=file_path)),
        ("Movement Fuzzing", lambda: run_movement_fuzzing(fuzz_runner, iterations, file_path)),
        ("Command Fuzzing", lambda: run_command_fuzzing(fuzz_runner, iterations, file_path)),
        ("Insertion Fuzzing", lambda: run_insertion_fuzzing(fuzz_runner, iterations, file_path)),
        ("Unicode Fuzzing", lambda: run_unicode_fuzzing(fuzz_runner, iterations, file_path)),
    ]

    all_results = []

    for strategy_name, strategy_func in strategies:
        print(f"\n{'=' * 60}")
        print(f"STRATEGY: {strategy_name}")
        print(f"{'=' * 60}")

        try:
            results = strategy_func()
            all_results.extend(results)

            success_count = sum(1 for r in results if r.success)
            success_rate = success_count / len(results) if results else 0
            print(
                f"{strategy_name}: {success_count}/{len(results)} passed ({success_rate:.1%})"
            )

        except Exception as e:
            logger.error(f"{strategy_name} failed: {str(e)}", exc_info=True)

    # Overall summary
    total_success = sum(1 for r in all_results if r.success)
    total_rate = total_success / len(all_results) if all_results else 0

    print(f"\n{'=' * 60}")
    print(f"AGGRESSIVE FUZZING SUMMARY FOR {editor.upper()}")
    print(f"{'=' * 60}")
    print(f"Total sequences: {len(all_results)}")
    print(f"Successful: {total_success}")
    print(f"Failed: {len(all_results) - total_success}")
    print(f"Success rate: {total_rate:.1%}")

    # Analyze failures
    failures = [r for r in all_results if not r.success]
    if failures:
        print(f"\nFailure Analysis ({len(failures)} failures):")

        error_patterns = {}
        for failure in failures:
            error_type = failure.error or "Unknown error"
            error_patterns[error_type] = error_patterns.get(error_type, 0) + 1

        for error, count in sorted(
            error_patterns.items(), key=lambda x: x[1], reverse=True
        ):
            print(f"  {error}: {count}")

    # Save detailed results
    import json

    results_data = {
        "editor": editor,
        "total_sequences": len(all_results),
        "successful": total_success,
        "failed": len(all_results) - total_success,
        "success_rate": total_rate,
        "failure_patterns": error_patterns if failures else {},
        "detailed_results": [
            {
                "sequence": r.sequence,
                "success": r.success,
                "error": r.error,
                "execution_time": r.execution_time,
            }
            for r in all_results
        ],
    }

    results_file = f"logs/aggressive_fuzz_{editor}.json"
    Path("logs").mkdir(exist_ok=True)
    with open(results_file, "w") as f:
        json.dump(results_data, f, indent=2, default=str)
    print(f"\nDetailed results saved to: {results_file}")

    return 0 if total_rate > 0.7 else 1


def run_movement_fuzzing(fuzz_runner: FuzzRunner, iterations: int, file_path: str | None = None):
    """Run movement-focused fuzzing."""
    fuzzer = InputFuzzer()
    results = []

    for i in range(iterations):
        # Generate movement-heavy sequences
        movements = [
            "h",
            "j",
            "k",
            "l",
            "gg",
            "G",
            "0",
            "$",
            "^",
            "w",
            "b",
            "e",
            "ge",
            "<Up>",
            "<Down>",
            "<Left>",
            "<Right>",
            "<Home>",
            "<End>",
            "<PageUp>",
            "<PageDown>",
        ]

        # Create sequences with lots of movement
        sequence = "".join(
            [fuzzer.special_keys[0]]  # Start with ESC to ensure normal mode
            + [fuzzer.special_keys[0]]
            + [
                movements[j % len(movements)] + fuzzer.special_keys[0]
                for j in range(random.randint(5, 20))
            ]
        )

        result = fuzz_runner.run_sequence(sequence, file_path=file_path)
        results.append(result)

        if (i + 1) % 10 == 0:
            success_rate = sum(1 for r in results if r.success) / len(results)
            print(
                f"Movement fuzzing progress: {i + 1}/{iterations}, Success rate: {success_rate:.1%}"
            )

    return results


def run_command_fuzzing(fuzz_runner: FuzzRunner, iterations: int, file_path: str | None = None):
    """Run command-mode fuzzing."""
    import random

    results = []

    # Dangerous/garbage commands
    dangerous_commands = [
        ":",
        ":!",
        ":q!",
        ":qall!",
        ":wq!",
        ":x!",
        ":help",
        ":version",
        ":set all",
        ":map",
        ":unmap",
        ":ab",
        ":unab",
        ":highlight",
        ":syntax",
        ":colorscheme",
        ":",
        "::",
        ":::",
        ":;",
        ":;;",
        ":/garbage",
        ":?garbage",
        ":s//g",
        ":%s",
        ":1",
        ":99999",
        ":999999",
        ":0",
        ":-1",
        ":%",
        ":$",
        ":command",
        ":function",
        ":let",
        ":execute",
        ":echo",
        ":call",
        ":source",
        ":runtime",
        ":packadd",
        ":loadview",
        ":mkview",
    ]

    for i in range(iterations):
        # Create command sequences
        num_commands = random.randint(1, 5)
        commands = [
            random.choice(dangerous_commands) + "<CR>" for _ in range(num_commands)
        ]
        sequence = "".join(commands)

        result = fuzz_runner.run_sequence(sequence, file_path=file_path)
        results.append(result)

        if (i + 1) % 10 == 0:
            success_rate = sum(1 for r in results if r.success) / len(results)
            print(
                f"Command fuzzing progress: {i + 1}/{iterations}, Success rate: {success_rate:.1%}"
            )

    return results


def run_insertion_fuzzing(fuzz_runner: FuzzRunner, iterations: int, file_path: str | None = None):
    """Run insertion-mode fuzzing."""
    import random
    import string

    results = []

    # Stressful text patterns
    stress_patterns = [
        "a" * 100,  # Long repeated chars
        "A" * 100,  # Uppercase
        "1" * 100,  # Numbers
        "!" * 100,  # Special chars
        string.printable * 10,  # All printable chars
        "😀" * 20,  # Emojis (might fail)
        "\t" * 50,  # Tabs
        "\n" * 20,  # Newlines
        " " * 100,  # Spaces
        "a\tb\tc\nd\ne\tf",  # Mixed whitespace
        "{{{{[[[[((()))]]]]}}}}",  # Brackets
        "`~!@#$%^&*()_+-=[]{}|;':\",./<>?",  # All specials
    ]

    for i in range(iterations):
        # Random mode entry and text
        mode_entry = random.choice(["i", "a", "o", "O", "I", "A", "s", "S"])
        text = random.choice(stress_patterns)
        sequence = mode_entry + text + "<ESC>"

        result = fuzz_runner.run_sequence(sequence, file_path=file_path)
        results.append(result)

        if (i + 1) % 10 == 0:
            success_rate = sum(1 for r in results if r.success) / len(results)
            print(
                f"Insertion fuzzing progress: {i + 1}/{iterations}, Success rate: {success_rate:.1%}"
            )

    return results


def run_unicode_fuzzing(fuzz_runner: FuzzRunner, iterations: int, file_path: str | None = None):
    """Run unicode-heavy fuzzing."""
    fuzzer = InputFuzzer()
    results = []

    for i in range(iterations):
        # Generate unicode heavy sequence
        sequence = fuzzer.generate_unicode_sequence(length=random.randint(20, 100))
        
        result = fuzz_runner.run_sequence(sequence, file_path=file_path)
        results.append(result)

        if (i + 1) % 10 == 0:
            success_rate = sum(1 for r in results if r.success) / len(results)
            print(
                f"Unicode fuzzing progress: {i + 1}/{iterations}, Success rate: {success_rate:.1%}"
            )
            
    return results


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Aggressive fuzzing for editors")
    parser.add_argument("editor", choices=["videre", "nvim"], help="Editor to test")
    parser.add_argument(
        "-i",
        "--iterations",
        type=int,
        default=50,
        help="Iterations per strategy (default: 50)",
    )
    parser.add_argument(
        "-f", "--file", help="File to open in the editor"
    )

    args = parser.parse_args()

    return run_aggressive_fuzz(args.editor, args.iterations, args.file)


if __name__ == "__main__":
    import random  # Need this for the run_*_fuzzing functions

    sys.exit(main())
