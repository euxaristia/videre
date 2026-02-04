"""videre editor driver for benchmarking."""

import subprocess
import os
import sys
from pathlib import Path
from typing import Optional

# Add drivers to path for imports
sys.path.insert(0, str(Path(__file__).parent))
from base_driver import EditorDriver


class VidereDriver(EditorDriver):
    """Driver for videre editor."""

    def __init__(self, videre_path: Optional[str] = None):
        super().__init__("videre")
        if videre_path is None:
            # Default to built videre binary
            videre_path = os.path.join(
                os.path.dirname(__file__),
                "../../.build/release/videre",
            )
        self.videre_path = os.path.abspath(videre_path)

    def get_command(self, file_path: Optional[str] = None) -> list:
        """Get command to launch videre."""
        cmd = [self.videre_path]
        if file_path:
            cmd.append(file_path)
        return cmd

    def is_ready(self, output: str) -> bool:
        """Check if videre is ready."""
        # videre displays the welcome message or file content when ready
        # Look for any terminal output indicating ready state
        return len(output) > 0 or "~" in output

    def get_quit_keys(self) -> str:
        """Get keys to quit videre."""
        return "<ESC>:q<CR>"
