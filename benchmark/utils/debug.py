"""Debug utilities for enhanced logging and error tracking."""

import logging
import sys
import time
import traceback
from typing import Optional, Dict, Any, List
from pathlib import Path
from dataclasses import dataclass
from datetime import datetime


@dataclass
class DebugEvent:
    """A debug event with timestamp and context."""

    timestamp: float
    level: str
    message: str
    context: Dict[str, Any] | None = None
    traceback: str | None = None


class DebugLogger:
    """Enhanced logging with structured debug information."""

    def __init__(
        self,
        name: str = "benchmark",
        log_file: str | None = None,
        verbose: bool = False,
    ):
        self.name = name
        self.verbose = verbose
        self.events: List[DebugEvent] = []

        # Setup logging
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.DEBUG if verbose else logging.INFO)

        # Clear existing handlers
        self.logger.handlers.clear()

        # Console handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.DEBUG if verbose else logging.INFO)
        console_formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )
        console_handler.setFormatter(console_formatter)
        self.logger.addHandler(console_handler)

        # File handler if specified
        if log_file:
            file_handler = logging.FileHandler(log_file)
            file_handler.setLevel(logging.DEBUG)
            file_formatter = logging.Formatter(
                "%(asctime)s - %(name)s - %(levelname)s - %(funcName)s:%(lineno)d - %(message)s"
            )
            file_handler.setFormatter(file_formatter)
            self.logger.addHandler(file_handler)

    def _add_event(
        self,
        level: str,
        message: str,
        context: Dict[str, Any] | None = None,
        exc_info: bool = False,
    ):
        """Add a debug event to the event log."""
        event = DebugEvent(
            timestamp=time.perf_counter(),
            level=level,
            message=message,
            context=context,
            traceback=traceback.format_exc() if exc_info else None,
        )
        self.events.append(event)

    def debug(self, message: str, context: Dict[str, Any] | None = None):
        """Log debug message."""
        if self.verbose:
            self.logger.debug(message)
        self._add_event("DEBUG", message, context)

    def info(self, message: str, context: Dict[str, Any] | None = None):
        """Log info message."""
        self.logger.info(message)
        self._add_event("INFO", message, context)

    def warning(self, message: str, context: Dict[str, Any] | None = None):
        """Log warning message."""
        self.logger.warning(message)
        self._add_event("WARNING", message, context)

    def error(
        self, message: str, context: Dict[str, Any] | None = None, exc_info: bool = True
    ):
        """Log error message."""
        self.logger.error(message, exc_info=exc_info)
        self._add_event("ERROR", message, context, exc_info)

    def critical(
        self, message: str, context: Dict[str, Any] | None = None, exc_info: bool = True
    ):
        """Log critical message."""
        self.logger.critical(message, exc_info=exc_info)
        self._add_event("CRITICAL", message, context, exc_info)

    def get_events_by_level(self, level: str) -> List[DebugEvent]:
        """Get all events of a specific level."""
        return [event for event in self.events if event.level == level]

    def get_events_since(self, timestamp: float) -> List[DebugEvent]:
        """Get all events since a given timestamp."""
        return [event for event in self.events if event.timestamp >= timestamp]

    def save_events(self, file_path: str):
        """Save events to a JSON file."""
        import json

        events_data = []
        for event in self.events:
            event_dict = {
                "timestamp": event.timestamp,
                "level": event.level,
                "message": event.message,
                "context": event.context,
                "traceback": event.traceback,
            }
            events_data.append(event_dict)

        with open(file_path, "w") as f:
            json.dump(events_data, f, indent=2)

    def print_summary(self):
        """Print a summary of all events."""
        if not self.events:
            print("No events recorded.")
            return

        level_counts = {}
        for event in self.events:
            level_counts[event.level] = level_counts.get(event.level, 0) + 1

        print(f"\nDebug Summary - {len(self.events)} total events:")
        for level, count in sorted(level_counts.items()):
            print(f"  {level}: {count}")

        # Show errors and warnings
        errors = self.get_events_by_level("ERROR")
        warnings = self.get_events_by_level("WARNING")

        if errors:
            print(f"\nErrors ({len(errors)}):")
            for i, error in enumerate(errors[-5:], 1):  # Show last 5 errors
                print(f"  {i}. {error.message}")

        if warnings:
            print(f"\nWarnings ({len(warnings)}):")
            for i, warning in enumerate(warnings[-5:], 1):  # Show last 5 warnings
                print(f"  {i}. {warning.message}")


class DebugContext:
    """Context manager for debugging operations."""

    def __init__(
        self, logger: DebugLogger, operation: str, context: Dict[str, Any] | None = None
    ):
        self.logger = logger
        self.operation = operation
        self.context = context or {}
        self.start_time = None

    def __enter__(self):
        self.start_time = time.perf_counter()
        self.logger.debug(f"Starting {self.operation}", self.context)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        duration = time.perf_counter() - (self.start_time or 0)
        context = {**self.context, "duration": duration}

        if exc_type is None:
            self.logger.debug(f"Completed {self.operation} in {duration:.3f}s", context)
        else:
            self.logger.error(
                f"Failed {self.operation} after {duration:.3f}s", context, exc_info=True
            )

        return False  # Don't suppress exceptions


def setup_debug_logging(verbose: bool = False, log_dir: str = "logs") -> DebugLogger:
    """Setup debug logging for the benchmark session."""
    # Create logs directory
    log_path = Path(log_dir)
    log_path.mkdir(exist_ok=True)

    # Create timestamped log file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_path / f"benchmark_{timestamp}.log"

    logger = DebugLogger(log_file=str(log_file), verbose=verbose)
    logger.info(
        "Debug logging initialized", {"log_file": str(log_file), "verbose": verbose}
    )

    return logger


class ErrorTracker:
    """Tracks and analyzes errors across test runs."""

    def __init__(self, logger: DebugLogger):
        self.logger = logger
        self.errors: List[Dict[str, Any]] = []

    def record_error(self, error: Exception, context: Dict[str, Any] | None = None):
        """Record an error with context."""
        error_info = {
            "timestamp": time.perf_counter(),
            "type": type(error).__name__,
            "message": str(error),
            "context": context or {},
            "traceback": traceback.format_exc(),
        }
        self.errors.append(error_info)
        self.logger.error(
            f"Error recorded: {type(error).__name__}: {str(error)}",
            context,
            exc_info=False,
        )

    def get_error_patterns(self) -> Dict[str, int]:
        """Get frequency of error types."""
        patterns = {}
        for error in self.errors:
            error_type = error["type"]
            patterns[error_type] = patterns.get(error_type, 0) + 1
        return patterns

    def get_recent_errors(self, count: int = 10) -> List[Dict[str, Any]]:
        """Get the most recent errors."""
        return self.errors[-count:] if self.errors else []

    def save_errors(self, file_path: str):
        """Save error log to file."""
        import json

        with open(file_path, "w") as f:
            json.dump(self.errors, f, indent=2, default=str)
