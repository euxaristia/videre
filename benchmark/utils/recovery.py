"""Error recovery and resilience utilities for benchmarking."""

import time
import signal
import subprocess
import sys
from typing import Optional, Callable, Any, Dict
from pathlib import Path
from .debug import DebugLogger, ErrorTracker


class RecoveryManager:
    """Manages error recovery for failed test runs."""

    def __init__(
        self, logger: DebugLogger, max_retries: int = 3, retry_delay: float = 1.0
    ):
        self.logger = logger
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self.error_tracker = ErrorTracker(logger)

    def retry_operation(
        self,
        operation: Callable,
        operation_name: str,
        context: Dict[str, Any] | None = None,
    ) -> Any:
        """Retry an operation with exponential backoff."""
        last_exception = None

        for attempt in range(self.max_retries + 1):
            try:
                if attempt > 0:
                    delay = self.retry_delay * (2 ** (attempt - 1))
                    retry_context = dict(context) if context else {}
                    retry_context.update({"attempt": attempt + 1, "delay": delay})
                    self.logger.warning(
                        f"Retrying {operation_name} (attempt {attempt + 1}) after {delay:.1f}s delay",
                        retry_context,
                    )
                    time.sleep(delay)

                result = operation()

                if attempt > 0:
                    self.logger.info(
                        f"Operation {operation_name} succeeded on attempt {attempt + 1}"
                    )

                return result

            except Exception as e:
                last_exception = e
                error_context = dict(context) if context else {}
                error_context.update(
                    {
                        "operation": operation_name,
                        "attempt": attempt + 1,
                        "max_retries": self.max_retries + 1,
                    }
                )
                self.error_tracker.record_error(e, error_context)

                if attempt == self.max_retries:
                    self.logger.error(
                        f"Operation {operation_name} failed after {self.max_retries + 1} attempts"
                    )
                    break
                else:
                    self.logger.warning(
                        f"Operation {operation_name} failed on attempt {attempt + 1}: {str(e)}"
                    )

        if last_exception is not None:
            raise last_exception
        else:
            raise RuntimeError("Operation failed with unknown error")

    def cleanup_failed_processes(self):
        """Clean up any orphaned processes from failed runs."""
        self.logger.info("Cleaning up failed processes")

        # Look for common editor processes
        editor_commands = ["vite", "nvim", "vim", "vi"]

        for cmd in editor_commands:
            try:
                # Find and kill processes
                result = subprocess.run(
                    ["pgrep", "-f", cmd], capture_output=True, text=True, timeout=5
                )

                if result.returncode == 0:
                    pids = result.stdout.strip().split("\n")
                    for pid in pids:
                        try:
                            subprocess.run(["kill", "-TERM", pid], timeout=2)
                            self.logger.debug(
                                f"Sent TERM signal to process {pid} ({cmd})"
                            )
                        except subprocess.TimeoutExpired:
                            try:
                                subprocess.run(["kill", "-KILL", pid], timeout=2)
                                self.logger.warning(
                                    f"Force killed process {pid} ({cmd})"
                                )
                            except:
                                pass

            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

        # Clean up temporary files
        self._cleanup_temp_files()

    def _cleanup_temp_files(self):
        """Clean up temporary files that might be left behind."""
        import glob
        import tempfile

        temp_patterns = ["/tmp/vite*", "/tmp/nvim*", "/tmp/.vite*", "/tmp/.nvim*"]

        cleaned_count = 0
        for pattern in temp_patterns:
            for file_path in glob.glob(pattern):
                try:
                    if Path(file_path).is_file():
                        Path(file_path).unlink()
                    else:
                        # For directories, use rmtree
                        import shutil

                        shutil.rmtree(file_path)
                    cleaned_count += 1
                except (PermissionError, FileNotFoundError):
                    pass

        if cleaned_count > 0:
            self.logger.info(f"Cleaned up {cleaned_count} temporary files/directories")


class CircuitBreaker:
    """Circuit breaker pattern for failing operations."""

    def __init__(self, failure_threshold: int = 5, recovery_timeout: float = 60.0):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.last_failure_time = 0
        self.state = "CLOSED"  # CLOSED, OPEN, HALF_OPEN

    def call(self, operation: Callable, operation_name: str) -> Any:
        """Call operation with circuit breaker protection."""
        if self.state == "OPEN":
            if time.time() - self.last_failure_time > self.recovery_timeout:
                self.state = "HALF_OPEN"
            else:
                raise RuntimeError(f"Circuit breaker OPEN for {operation_name}")

        try:
            result = operation()

            if self.state == "HALF_OPEN":
                self.state = "CLOSED"
                self.failure_count = 0

            return result

        except Exception as e:
            self.failure_count += 1
            self.last_failure_time = time.time()

            if self.failure_count >= self.failure_threshold:
                self.state = "OPEN"

            raise e

    def reset(self):
        """Reset the circuit breaker."""
        self.failure_count = 0
        self.last_failure_time = 0
        self.state = "CLOSED"


class GracefulShutdown:
    """Handle graceful shutdown with cleanup."""

    def __init__(self, logger: DebugLogger):
        self.logger = logger
        self.cleanup_handlers = []
        self.shutdown_requested = False

        # Register signal handlers
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

    def register_cleanup(self, handler: Callable):
        """Register a cleanup handler."""
        self.cleanup_handlers.append(handler)

    def _signal_handler(self, signum, frame):
        """Handle shutdown signals."""
        if not self.shutdown_requested:
            self.shutdown_requested = True
            self.logger.info(f"Received signal {signum}, initiating graceful shutdown")

            # Run cleanup handlers
            for handler in self.cleanup_handlers:
                try:
                    handler()
                except Exception as e:
                    self.logger.error(f"Cleanup handler failed: {str(e)}")

            # Exit gracefully
            sys.exit(0)

    def is_shutdown_requested(self) -> bool:
        """Check if shutdown has been requested."""
        return self.shutdown_requested


class HealthChecker:
    """Check health of external dependencies."""

    def __init__(self, logger: DebugLogger):
        self.logger = logger

    def check_editor_health(self, editor_name: str) -> bool:
        """Check if an editor is available and healthy."""
        try:
            if editor_name == "vite":
                # Check if vite binary exists
                vite_path = (
                    Path(__file__).parent.parent.parent / ".build" / "release" / "vite"
                )
                if not vite_path.exists():
                    self.logger.error(f"vite binary not found at {vite_path}")
                    return False

                # Try to run --help or similar
                result = subprocess.run(
                    [str(vite_path)], capture_output=True, text=True, timeout=3
                )

                # We don't care about exit code, just that it runs
                return True

            elif editor_name in ["nvim", "vim", "vi"]:
                # Check if editor is in PATH
                result = subprocess.run(
                    [editor_name, "--version"],
                    capture_output=True,
                    text=True,
                    timeout=3,
                )
                return result.returncode == 0

            return False

        except Exception as e:
            self.logger.error(f"Health check failed for {editor_name}: {str(e)}")
            return False

    def check_system_resources(self) -> Dict[str, Any]:
        """Check system resources."""
        import psutil

        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage("/")

            return {
                "cpu_percent": cpu_percent,
                "memory_percent": memory.percent,
                "disk_percent": (disk.used / disk.total) * 100,
                "available_memory_gb": memory.available / (1024**3),
                "healthy": cpu_percent < 90 and memory.percent < 90,
            }
        except ImportError:
            # psutil not available
            return {"healthy": True, "note": "psutil not installed"}
        except Exception as e:
            self.logger.error(f"System resource check failed: {str(e)}")
            return {"healthy": False, "error": str(e)}
