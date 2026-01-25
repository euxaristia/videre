# vite Benchmark Suite

Automated benchmark suite comparing vite's performance against Neovim for basic editor operations.

## Quick Start

### Run All Benchmarks
```bash
./benchmark/run_benchmarks.sh
```

### Run with Options
```bash
python3 benchmark/benchmark.py --help

# Run with custom iterations
python3 benchmark/benchmark.py -i 10

# Test only vite (skip Neovim)
python3 benchmark/benchmark.py --skip-nvim
```

## What Gets Benchmarked

### 1. Startup Time
Measures time from process spawn to editor ready, tested with files of varying sizes:
- Empty file
- 100 lines
- 1,000 lines
- 10,000 lines

### 2. Text Insertion
Measures time to insert text in insert mode:
- **Single characters:** 100 insertions of single `a` character
- **Words:** 50 insertions of "word "
- **Lines:** 20 insertions of full lines with Enter

### 3. Cursor Movement
Measures time for various motion commands:
- **hjkl:** 1,000 basic arrow movements
- **Word motions:** 500 w/b/e commands (forward/back/end-of-word)
- **Line motions:** 500 0/$ commands (start/end-of-line)
- **Jumps:** 100 gg/G commands (file start/end)

### 4. File Operations
Measures time for save/load operations:
- **Load:** Reading files of various sizes from disk
- **Save:** Writing modified files back to disk

## Results

Results are automatically saved in multiple formats:

### JSON Format
Location: `benchmark/results/benchmark_TIMESTAMP.json`

Contains structured data with timing statistics:
```json
{
  "metadata": {
    "vite_version": "...",
    "nvim_version": "..."
  },
  "results": {
    "startup": {
      "vite": {
        "mean": 0.023,
        "median": 0.022,
        "stddev": 0.002,
        "min": 0.021,
        "max": 0.025,
        "count": 5
      },
      "nvim": { ... }
    }
  }
}
```

### Markdown Format
Location: `benchmark/results/benchmark_TIMESTAMP.md`

Human-readable tables comparing both editors with speedup calculations.

### Console Output
Summary printed to terminal with all timing statistics.

## Architecture

### Drivers (`benchmark/drivers/`)
- **base_driver.py:** Abstract base class with PTY automation
- **vite_driver.py:** vite-specific driver
- **nvim_driver.py:** Neovim-specific driver

### Scenarios (`benchmark/scenarios/`)
- **startup.py:** Startup time tests
- **insertion.py:** Text insertion tests
- **movement.py:** Cursor movement tests
- **fileops.py:** File operation tests

### Utilities (`benchmark/utils/`)
- **timing.py:** Timer class and statistics utilities
- **test_data.py:** Test file generator and cleanup
- **reporting.py:** Result formatting and reporting

### Test Files (`benchmark/fixtures/`)
Generated automatically:
- empty.txt (0 lines)
- small_100.txt (100 lines)
- medium_1k.txt (1,000 lines)
- large_10k.txt (10,000 lines)
- huge_100k.txt (100,000 lines)

## How It Works

The benchmark system uses Python's `pty` module to automate both editors:

1. **PTY Automation:** Creates a pseudo-terminal to communicate with the editor
2. **Keystroke Injection:** Sends keystrokes programmatically to both editors
3. **Timing:** Uses `time.perf_counter()` for high-resolution timing
4. **Multiple Iterations:** Runs each test 5 times and reports statistics
5. **Fair Comparison:** Runs identical operations on both editors

## Technical Details

### PTY Communication
- Uses `pty.forkexec()` to launch editors in a pseudo-terminal
- Sends keystrokes as raw bytes via `os.write()`
- Reads output via `os.read()` to detect ready state
- Handles special keys: arrows, ESC, Ctrl+X combinations

### Timing Strategy
- High-resolution timer with `time.perf_counter()`
- Records mean, median, standard deviation, min, and max
- Each test runs 5 iterations for statistical validity
- Results include completion time, not just keystroke sending

### Special Key Support
- `<CR>` - Carriage return
- `<ESC>` - Escape key
- `<C-c>` - Ctrl+C
- Arrow keys: `<Up>`, `<Down>`, `<Left>`, `<Right>`
- And more...

## Requirements

### System
- Python 3.7+
- Linux or macOS (PTY-based)
- Swift 5.9+ (to build vite)

### Dependencies
- Neovim (optional, for comparison)
- Built vite binary (auto-built by run_benchmarks.sh)

### Installation
```bash
# Python is usually pre-installed
# For Neovim:
sudo apt install neovim  # Ubuntu/Debian
brew install neovim      # macOS
```

## Performance Notes

- First run may be slower due to system caching
- File I/O tests (save/load) may vary based on system load
- Consider running benchmarks multiple times for consistent results
- Standard deviation should be low for valid comparisons

## Troubleshooting

### "nvim not found"
Install Neovim or skip with `--skip-nvim` flag.

### PTY Errors
Ensure you're not in a restricted shell environment. PTY operations require proper terminal capabilities.

### Timeout Errors
Increase iterations with smaller samples first: `python3 benchmark/benchmark.py -i 2`

### High Variance in Results
Run again or increase iterations for more stable statistics.

## Adding New Benchmarks

1. Create a new test function in `scenarios/`
2. Import in `benchmark.py`
3. Call from `run_benchmarks()`
4. Results are automatically collected and reported

Example:
```python
def benchmark_custom(driver_class, iterations: int = 5) -> Dict:
    """Custom benchmark."""
    timer = Timer()
    for _ in range(iterations):
        driver = driver_class()
        try:
            # Your test here
            pass
        finally:
            driver.quit(force=True)
    return timer.get_stats()
```

## Files Created

```
benchmark/
├── benchmark.py              # Main benchmark runner
├── run_benchmarks.sh        # Convenience wrapper script
├── README.md                # This file
├── __init__.py
├── drivers/
│   ├── __init__.py
│   ├── base_driver.py       # PTY automation base class
│   ├── vite_driver.py       # vite driver
│   └── nvim_driver.py       # Neovim driver
├── scenarios/
│   ├── __init__.py
│   ├── startup.py           # Startup benchmarks
│   ├── insertion.py         # Insertion benchmarks
│   ├── movement.py          # Movement benchmarks
│   └── fileops.py           # File operation benchmarks
├── utils/
│   ├── __init__.py
│   ├── timing.py            # Timer and statistics
│   ├── test_data.py         # Test file generation
│   └── reporting.py         # Result formatting
├── fixtures/                # Generated test files (created at runtime)
├── results/                 # Benchmark results (JSON and Markdown)
└── [other files created by benchmarks]
```

## Example Output

```
================================================================================
BENCHMARK RESULTS
================================================================================
Timestamp: 2025-01-24 15:30:45
vite version: 0.1.0
nvim version: NVIM v0.11.5

Startup
----------------

  empty:
    vite     - Mean: 0.0234s, Median: 0.0231s, StdDev: 0.0012s
    nvim     - Mean: 0.0456s, Median: 0.0453s, StdDev: 0.0018s

  100_lines:
    vite     - Mean: 0.0241s, Median: 0.0238s, StdDev: 0.0015s
    nvim     - Mean: 0.0463s, Median: 0.0460s, StdDev: 0.0020s

...
```

## License

Same as vite project.
