"""Base driver for editor automation via PTY."""

import os
import sys
import time
import signal
import pty
import subprocess
from abc import ABC, abstractmethod
from typing import Optional
import fcntl
import termios


class EditorDriver(ABC):
    """Abstract base class for editor drivers using PTY automation."""

    def __init__(self, editor_name: str):
        self.editor_name = editor_name
        self.process = None
        self.master_fd = None
        self.child_pid = None
        self.ready_time = None

    @abstractmethod
    def get_command(self, file_path: Optional[str] = None) -> list:
        """Get the command to launch the editor."""
        pass

    @abstractmethod
    def is_ready(self, output: str) -> bool:
        """Check if editor is ready based on output."""
        pass

    @abstractmethod
    def get_quit_keys(self) -> str:
        """Get keys to quit the editor."""
        pass

    def start(self, file_path: Optional[str] = None) -> float:
        """Start the editor and return ready time."""
        cmd = self.get_command(file_path)
        start_time = time.perf_counter()

        # Fork and exec in PTY
        try:
            self.child_pid, self.master_fd = pty.forkexec(
                cmd[0], cmd, env=os.environ.copy()
            )
        except AttributeError:
            # forkexec not available, use fork() + exec()
            self.child_pid, self.master_fd = pty.fork()

            if self.child_pid == 0:
                # Child process
                os.execvp(cmd[0], cmd)
            # Parent process continues
            pass

        # Set master fd to non-blocking
        fl = fcntl.fcntl(self.master_fd, fcntl.F_GETFL)
        fcntl.fcntl(self.master_fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)

        # Wait for ready
        if self.wait_for_ready(timeout=5.0):
            self.ready_time = time.perf_counter() - start_time
            return self.ready_time
        else:
            raise RuntimeError(f"{self.editor_name} failed to become ready")

    def send_keys(self, keys: str, delay: float = 0.01) -> None:
        """Send keystrokes to the editor."""
        if self.master_fd is None:
            raise RuntimeError("Editor not running")

        # Convert keys to bytes
        key_bytes = self._convert_keys(keys)

        # Send with small delays between characters
        for byte in key_bytes:
            os.write(self.master_fd, bytes([byte]))
            time.sleep(delay)

    def _convert_keys(self, keys: str) -> bytes:
        """Convert key specification to bytes."""
        output = bytearray()
        i = 0
        while i < len(keys):
            if keys[i] == "<" and i + 1 < len(keys):
                # Handle special keys like <CR>, <ESC>, <C-c>, etc.
                end = keys.find(">", i)
                if end != -1:
                    special = keys[i + 1 : end]
                    output.extend(self._special_key_bytes(special))
                    i = end + 1
                    continue

            # Regular character
            output.append(ord(keys[i]))
            i += 1

        return bytes(output)

    def _special_key_bytes(self, key: str) -> bytes:
        """Convert special key names to bytes."""
        special_keys = {
            "CR": b"\r",
            "NL": b"\n",
            "ESC": b"\x1b",
            "BS": b"\x08",
            "Tab": b"\t",
            "Space": b" ",
            "Up": b"\x1b[A",
            "Down": b"\x1b[B",
            "Right": b"\x1b[C",
            "Left": b"\x1b[D",
            "Home": b"\x1bOH",
            "End": b"\x1bOF",
            "PageUp": b"\x1b[5~",
            "PageDown": b"\x1b[6~",
            "Delete": b"\x1b[3~",
        }

        # Handle Ctrl+X combinations
        if key.startswith("C-"):
            char = key[2]
            return bytes([ord(char) - 96])  # Ctrl modifier

        return special_keys.get(key, b"")

    def wait_for_ready(self, timeout: float = 5.0) -> bool:
        """Wait for editor to be ready."""
        start_time = time.perf_counter()
        output = ""

        while time.perf_counter() - start_time < timeout:
            try:
                chunk = os.read(self.master_fd, 4096)
                if chunk:
                    output += chunk.decode("utf-8", errors="replace")
                    if self.is_ready(output):
                        return True
            except BlockingIOError:
                pass
            except OSError:
                break

            time.sleep(0.05)

        return False

    def read_output(self, timeout: float = 0.5) -> str:
        """Read available output from editor."""
        output = ""
        start_time = time.perf_counter()

        while time.perf_counter() - start_time < timeout:
            try:
                chunk = os.read(self.master_fd, 4096)
                if chunk:
                    output += chunk.decode("utf-8", errors="replace")
                else:
                    break
            except BlockingIOError:
                pass
            except OSError:
                break

            time.sleep(0.01)

        return output

    def quit(self, force: bool = False) -> float:
        """Quit the editor and return time taken."""
        quit_start = time.perf_counter()

        if force:
            self.send_keys("<ESC>:q!<CR>", delay=0.02)
        else:
            self.send_keys("<ESC>:q<CR>", delay=0.02)

        # Wait for process to exit
        max_wait = 5.0
        while time.perf_counter() - quit_start < max_wait:
            try:
                pid, status = os.waitpid(self.child_pid, os.WNOHANG)
                if pid == self.child_pid:
                    quit_time = time.perf_counter() - quit_start
                    self.cleanup()
                    return quit_time
            except ChildProcessError:
                # Process already exited
                quit_time = time.perf_counter() - quit_start
                self.cleanup()
                return quit_time

            time.sleep(0.05)

        # Force kill if not exited
        try:
            os.kill(self.child_pid, signal.SIGTERM)
            os.waitpid(self.child_pid, 0)
        except ProcessLookupError:
            pass

        quit_time = time.perf_counter() - quit_start
        self.cleanup()
        return quit_time

    def cleanup(self):
        """Clean up resources."""
        if self.master_fd is not None:
            try:
                os.close(self.master_fd)
            except OSError:
                pass
            self.master_fd = None

        self.child_pid = None

    def __del__(self):
        """Ensure cleanup on deletion."""
        self.cleanup()
