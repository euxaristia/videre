"""Result reporting and formatting utilities."""

import json
import sys
from datetime import datetime
from typing import Dict, Optional
from pathlib import Path


class Reporter:
    """Generate benchmark reports in JSON and Markdown."""

    def __init__(self, output_dir: str = "benchmark/results"):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def save_json(self, results: Dict, metadata: Dict) -> Path:
        """Save results as JSON."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filepath = self.output_dir / f"benchmark_{timestamp}.json"

        data = {
            "metadata": metadata,
            "results": results,
            "timestamp": timestamp,
        }

        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)

        return filepath

    def save_markdown(self, results: Dict, metadata: Dict) -> Path:
        """Save results as Markdown."""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filepath = self.output_dir / f"benchmark_{timestamp}.md"

        lines = []
        lines.append("# Benchmark Results\n")
        lines.append(f"**Timestamp:** {timestamp}\n")
        lines.append(f"**vite version:** {metadata.get('vite_version', 'unknown')}\n")
        lines.append(f"**nvim version:** {metadata.get('nvim_version', 'unknown')}\n")
        lines.append("")

        for category, category_data in results.items():
            lines.append(f"## {self._format_category(category)}\n")

            # Collect all test names and editors
            test_names = set()
            editors = set()

            for test_name, test_data in category_data.items():
                test_names.add(test_name)
                if isinstance(test_data, dict):
                    for editor, stats in test_data.items():
                        if isinstance(stats, dict):
                            editors.add(editor)

            editors = sorted(editors)

            # Create comparison table
            if editors and test_names:
                lines.append("| Test | " + " | ".join(editors) + " | Speedup |\n")
                lines.append("|------|" + "|".join(["---" for _ in editors]) + "|--------|\n")

                for test in sorted(test_names):
                    if test in category_data:
                        test_data = category_data[test]
                        row = [f"`{test}`"]

                        times = {}
                        for editor in editors:
                            if editor in test_data and isinstance(test_data[editor], dict):
                                mean = test_data[editor].get("mean", 0)
                                times[editor] = mean
                                row.append(f"{mean:.4f}s")
                            else:
                                row.append("—")

                        # Calculate speedup
                        if len(editors) >= 2 and all(e in times for e in editors):
                            first_time = times[editors[0]]
                            second_time = times[editors[1]]
                            if second_time > 0:
                                speedup = first_time / second_time
                                row.append(f"{speedup:.2f}x")
                            else:
                                row.append("—")
                        else:
                            row.append("—")

                        lines.append("| " + " | ".join(row) + " |\n")

                lines.append("")

        with open(filepath, "w") as f:
            f.writelines(lines)

        return filepath

    def print_summary(self, results: Dict, metadata: Dict) -> None:
        """Print summary to console."""
        print("\n" + "=" * 80)
        print("BENCHMARK RESULTS")
        print("=" * 80)
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"vite version: {metadata.get('vite_version', 'unknown')}")
        print(f"nvim version: {metadata.get('nvim_version', 'unknown')}\n")

        for category, category_data in results.items():
            print(f"\n{self._format_category(category)}")
            print("-" * 80)

            for test_name, test_data in category_data.items():
                print(f"\n  {test_name}:")
                if isinstance(test_data, dict):
                    for editor, stats in test_data.items():
                        if isinstance(stats, dict):
                            mean = stats.get("mean", 0)
                            median = stats.get("median", 0)
                            stddev = stats.get("stddev", 0)
                            print(f"    {editor:8} - Mean: {mean:.4f}s, Median: {median:.4f}s, StdDev: {stddev:.4f}s")

        print("\n" + "=" * 80 + "\n")

    @staticmethod
    def _format_category(name: str) -> str:
        """Format category name for display."""
        return name.replace("_", " ").title()
