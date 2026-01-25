"""Neovim editor driver for benchmarking."""

import subprocess
import shutil
import sys
from pathlib import Path
from typing import Optional

# Add drivers to path for imports
sys.path.insert(0, str(Path(__file__).parent))
from base_driver import EditorDriver


class NvimDriver(EditorDriver):
    """Driver for Neovim editor."""

    def __init__(self, nvim_path: Optional[str] = None):
        super().__init__("nvim")
        if nvim_path is None:
            # Find nvim in PATH
            nvim_path = shutil.which("nvim")
            if nvim_path is None:
                raise RuntimeError("nvim not found in PATH")
        self.nvim_path = nvim_path

    def get_command(self, file_path: Optional[str] = None) -> list:
        """Get command to launch nvim."""
        # Use --noplugin to disable plugins for consistent benchmarks
        cmd = [self.nvim_path, "--noplugin", "-u", "NONE"]
        if file_path:
            cmd.append(file_path)
        return cmd

    def is_ready(self, output: str) -> bool:
        """Check if nvim is ready."""
        # nvim shows prompt or editor content when ready
        return len(output) > 0 or "~" in output

    def get_quit_keys(self) -> str:
        """Get keys to quit nvim."""
        return "<ESC>:q<CR>"
