"""Fuzzing utilities for stress testing editors."""

import random
import string
from typing import List, Dict, Any
from dataclasses import dataclass


@dataclass
class FuzzConfig:
    """Configuration for fuzzing parameters."""

    max_sequence_length: int = 100
    min_sequence_length: int = 5
    include_special_keys: bool = True
    include_unicode: bool = True
    seed: int | None = None


class InputFuzzer:
    """Generates random input sequences for fuzzing editors."""

    def __init__(self, config: FuzzConfig | None = None):
        self.config = config or FuzzConfig()
        if self.config.seed:
            random.seed(self.config.seed)

        self.special_keys = [
            "<CR>",
            "<ESC>",
            "<Tab>",
            "<BS>",
            "<Space>",
            "<Up>",
            "<Down>",
            "<Left>",
            "<Right>",
            "<Home>",
            "<End>",
            "<PageUp>",
            "<PageDown>",
            "<Delete>",
            "<C-a>",
            "<C-c>",
            "<C-v>",
            "<C-x>",
            "<C-z>",
            "<C-y>",
        ]

        self.unicode_chars = [
            "α",
            "β",
            "γ",
            "δ",
            "é",
            "ñ",
            "ü",
            "ç",
            "ø",
            "æ",
            "€",
            "¥",
            "£",
            "©",
            "®",
            "™",
            "°",
            "±",
            "×",
            "÷",
        ]

    def generate_sequence(self, length: int | None = None) -> str:
        """Generate a random input sequence."""
        if length is None:
            length = random.randint(
                self.config.min_sequence_length, self.config.max_sequence_length
            )

        sequence = []

        for _ in range(length):
            choice = random.random()

            if choice < 0.7:  # 70% regular characters
                sequence.append(
                    random.choice(
                        string.ascii_letters + string.digits + string.punctuation + " "
                    )
                )
            elif choice < 0.85 and self.config.include_special_keys:  # 15% special keys
                sequence.append(random.choice(self.special_keys))
            elif choice < 0.95 and self.config.include_unicode:  # 10% unicode
                sequence.append(random.choice(self.unicode_chars))
            else:  # 5% escape sequences
                sequence.append(f"<ESC>{random.choice('hjkl')}")

        return "".join(sequence)

    def generate_movement_sequence(self, length: int = 20) -> str:
        """Generate a sequence focused on movement operations."""
        movements = [
            "<Up>",
            "<Down>",
            "<Left>",
            "<Right>",
            "<Home>",
            "<End>",
            "<PageUp>",
            "<PageDown>",
            "<C-f>",
            "<C-b>",
            "gg",
            "G",
            "0",
            "$",
        ]
        sequence = []

        for _ in range(length):
            if random.random() < 0.8:  # 80% movements
                sequence.append(random.choice(movements))
            else:  # 20% other keys
                sequence.append(random.choice(["i", "ESC", "a", "o", "O"]))

        return "".join(sequence)

    def generate_insertion_sequence(
        self, text: str | None = None, length: int = 50
    ) -> str:
        """Generate a sequence for text insertion."""
        if text is None:
            text = "The quick brown fox jumps over the lazy dog. " * 3

        sequence = ["i"]  # Enter insert mode
        chars_to_insert = random.randint(10, length)

        for _ in range(chars_to_insert):
            sequence.append(
                random.choice(text + string.ascii_letters + string.digits + " ")
            )

        sequence.append("<ESC>")  # Exit insert mode
        return "".join(sequence)

    def generate_edge_case_sequences(self) -> List[str]:
        """Generate sequences targeting known edge cases."""
        sequences = []

        # Rapid key presses
        sequences.append("h" * 50)
        sequences.append("j" * 50)
        sequences.append("l" * 50)
        sequences.append("k" * 50)

        # Large file navigation
        sequences.append("G" + "j" * 100 + "gg" + "G")
        sequences.append("<C-f>" * 10 + "<C-b>" * 10)

        # Command mode edge cases
        sequences.append(":12345<CR>")  # Very large line number
        sequences.append(":!<invalid><CR>")  # Invalid command
        sequences.append(":w<CR>:q<CR>")  # Multiple commands

        # Buffer switching stress
        sequences.append(":bprev<CR>:bnext<CR>" * 10)

        # Unicode stress
        sequences.append("".join(self.unicode_chars * 5))

        # Special key combinations
        sequences.append("<C-a><C-c><C-v><C-x>" * 10)

        return sequences


@dataclass
class FuzzResult:
    """Result of a fuzzing run."""

    sequence: str
    success: bool
    error: str | None = None
    execution_time: float = 0.0
    output: str = ""


class FuzzRunner:
    """Runs fuzzing tests against editor drivers."""

    def __init__(self, driver_class, debug: bool = False):
        self.driver_class = driver_class
        self.debug = debug
        self.results: List[FuzzResult] = []

    def run_sequence(self, sequence: str, file_path: str | None = None) -> FuzzResult:
        """Run a single fuzz sequence."""
        driver = self.driver_class()
        result = FuzzResult(sequence=sequence, success=False)

        try:
            import time

            start_time = time.perf_counter()

            # Start editor
            driver.start(file_path)

            if self.debug:
                print(
                    f"Running sequence: {repr(sequence[:50])}{'...' if len(sequence) > 50 else ''}"
                )

            # Send sequence with reduced delay for fuzzing
            driver.send_keys(sequence, delay=0.001)

            # Give editor time to process
            driver.read_output(timeout=0.1)

            # Quit
            quit_time = driver.quit()

            result.success = True
            result.execution_time = time.perf_counter() - start_time + quit_time

        except Exception as e:
            result.success = False
            result.error = str(e)
            if self.debug:
                print(f"Error in sequence: {e}")

            # Force quit on error
            try:
                driver.quit(force=True)
            except:
                pass

        return result

    def run_fuzz_suite(
        self, num_sequences: int = 100, config: FuzzConfig | None = None
    ) -> List[FuzzResult]:
        """Run a complete fuzzing suite."""
        fuzzer = InputFuzzer(config)
        results = []

        # Generate random sequences
        for i in range(num_sequences):
            sequence = fuzzer.generate_sequence()
            result = self.run_sequence(sequence)
            results.append(result)

            if self.debug and (i + 1) % 10 == 0:
                success_rate = sum(1 for r in results if r.success) / len(results)
                print(
                    f"Progress: {i + 1}/{num_sequences}, Success rate: {success_rate:.2%}"
                )

        # Add edge case sequences
        edge_cases = fuzzer.generate_edge_case_sequences()
        for sequence in edge_cases:
            result = self.run_sequence(sequence)
            results.append(result)

        self.results.extend(results)
        return results

    def get_summary(self) -> Dict[str, Any]:
        """Get summary statistics of fuzzing results."""
        if not self.results:
            return {}

        total = len(self.results)
        successful = sum(1 for r in self.results if r.success)
        failed = total - successful

        errors = {}
        for result in self.results:
            if not result.success and result.error:
                errors[result.error] = errors.get(result.error, 0) + 1

        avg_time = sum(r.execution_time for r in self.results) / total

        return {
            "total_sequences": total,
            "successful": successful,
            "failed": failed,
            "success_rate": successful / total,
            "average_execution_time": avg_time,
            "error_distribution": errors,
        }
