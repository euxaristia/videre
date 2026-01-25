"""vite editor driver for benchmarking."""

import subprocess
import os
import sys
from pathlib import Path
from typing import Optional

# Add drivers to path for imports
sys.path.insert(0, str(Path(__file__).parent))
from base_driver import EditorDriver


class ViteDriver(EditorDriver):
    """Driver for vite editor."""

    def __init__(self, vite_path: Optional[str] = None):
        super().__init__("vite")
        if vite_path is None:
            # Default to built vite binary
            vite_path = os.path.join(
                os.path.dirname(__file__),
                "../../.build/release/vite",
            )
        self.vite_path = os.path.abspath(vite_path)

    def get_command(self, file_path: Optional[str] = None) -> list:
        """Get command to launch vite."""
        cmd = [self.vite_path]
        if file_path:
            cmd.append(file_path)
        return cmd

    def is_ready(self, output: str) -> bool:
        """Check if vite is ready."""
        # vite displays the welcome message or file content when ready
        # Look for any terminal output indicating ready state
        return len(output) > 0 or "~" in output

    def get_quit_keys(self) -> str:
        """Get keys to quit vite."""
        return "<ESC>:q<CR>"
