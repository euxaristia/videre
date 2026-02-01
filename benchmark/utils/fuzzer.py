"""Fuzzing utilities for stress testing editors."""

import random
import string
from typing import List, Dict, Any, Optional, Callable
from dataclasses import dataclass, field
from enum import Enum, auto


class BehaviorViolation(Enum):
    """Types of non-standard behavior that can be detected."""
    UNEXPECTED_EXIT = auto()      # Editor exited when it shouldn't have
    UNHANDLED_KEY = auto()        # Key caused a crash or undefined behavior
    STANDARD_KEY_MISBEHAVIOR = auto()  # Standard terminal key did wrong thing
    HANG = auto()                 # Editor became unresponsive
    CRASH = auto()                # Editor crashed with error


@dataclass
class BehaviorTest:
    """Defines a test for expected editor behavior."""
    name: str
    sequence: str
    should_exit: bool = False
    description: str = ""
    # If not None, this function validates the result
    validator: Optional[Callable[['BehaviorResult'], bool]] = None


@dataclass
class BehaviorResult:
    """Result of a behavior test."""
    test: BehaviorTest
    passed: bool
    violation: Optional[BehaviorViolation] = None
    error: Optional[str] = None
    process_exited: bool = False
    execution_time: float = 0.0


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

        # Keys that should NEVER cause an exit in a properly behaving editor
        # These are standard terminal/editor keys that users expect to work
        self.non_exit_keys = [
            # Standard copy/paste keys (terminal emulators send these)
            "<C-c>",      # Ctrl+C - should NOT exit (common mistake)
            "<C-v>",      # Ctrl+V - paste
            "<C-x>",      # Ctrl+X - cut
            "<C-z>",      # Ctrl+Z - undo (should not suspend in raw mode)
            "<C-a>",      # Ctrl+A - select all / increment
            "<C-b>",      # Ctrl+B - page up
            "<C-f>",      # Ctrl+F - page down
            "<C-d>",      # Ctrl+D - half page down (not exit)
            "<C-u>",      # Ctrl+U - half page up
            "<C-r>",      # Ctrl+R - redo
            "<C-g>",      # Ctrl+G - show file info
            "<C-l>",      # Ctrl+L - redraw screen
            "<C-n>",      # Ctrl+N - next line
            "<C-p>",      # Ctrl+P - previous line
            # Movement keys
            "<Up>", "<Down>", "<Left>", "<Right>",
            "<Home>", "<End>", "<PageUp>", "<PageDown>",
            # Basic editing that shouldn't exit
            "<BS>", "<Delete>", "<Tab>", "<Space>",
            "<ESC>",
        ]

        # Basic extended Latin/symbols (1-column width)
        self.unicode_chars = [
            "α", "β", "γ", "δ", "é", "ñ", "ü", "ç", "ø", "æ",
            "€", "¥", "£", "©", "®", "™", "°", "±", "×", "÷",
        ]

        # Wide characters that take 2 terminal columns - critical for display width bugs
        self.wide_chars = [
            # Common emoji
            "😀", "😎", "🎉", "🔥", "💨", "✨", "🍅", "🚀", "🦀", "✅",
            "❌", "⚙️", "📁", "💾", "🔍", "⚠️", "🐛", "🎯", "💡", "🔧",
            # CJK characters (Chinese/Japanese/Korean)
            "中", "文", "日", "本", "語", "한", "국", "어", "漢", "字",
            "東", "京", "北", "京", "上", "海", "台", "灣", "香", "港",
            # Japanese Hiragana/Katakana
            "あ", "い", "う", "え", "お", "ア", "イ", "ウ", "エ", "オ",
            # Fullwidth ASCII (2-column versions)
            "Ａ", "Ｂ", "Ｃ", "１", "２", "３", "！", "？", "（", "）",
        ]

        # Obscure/exotic Unicode for stress testing
        self.exotic_chars = [
            # Mayan numerals (U+1D2E0-U+1D2F3)
            "𝋀", "𝋁", "𝋂", "𝋃", "𝋄", "𝋅", "𝋆", "𝋇", "𝋈", "𝋉",
            # Egyptian hieroglyphs (U+13000-U+1342F)
            "𓀀", "𓀁", "𓀂", "𓀃", "𓁀", "𓁁", "𓂀", "𓃀", "𓄀", "𓅀",
            # Cuneiform (U+12000-U+123FF)
            "𒀀", "𒀁", "𒀂", "𒀃", "𒁀", "𒁁", "𒂀", "𒃀", "𒄀", "𒅀",
            # Gothic (U+10330-U+1034F)
            "𐌰", "𐌱", "𐌲", "𐌳", "𐌴", "𐌵", "𐌶", "𐌷", "𐌸", "𐌹",
            # Linear B (U+10000-U+1007F)
            "𐀀", "𐀁", "𐀂", "𐀃", "𐀄", "𐀅", "𐀐", "𐀑", "𐀒", "𐀓",
            # Musical symbols
            "𝄞", "𝄢", "𝅗𝅥", "𝅘𝅥", "𝅘𝅥𝅮", "𝄀", "𝄁", "𝄂", "𝄃", "𝄄",
            # Alchemical symbols
            "🜀", "🜁", "🜂", "🜃", "🜄", "🜅", "🜆", "🜇", "🜈", "🜉",
            # Domino tiles
            "🁣", "🁤", "🁥", "🁦", "🁧", "🁨", "🁩", "🁪", "🁫", "🁬",
            # Playing cards
            "🂡", "🂢", "🂣", "🂤", "🂥", "🂦", "🂧", "🂨", "🂩", "🂪",
            # Chess symbols
            "♔", "♕", "♖", "♗", "♘", "♙", "♚", "♛", "♜", "♝",
        ]

        # Zero-width and combining characters (display width edge cases)
        self.zero_width_chars = [
            "\u200B",  # Zero-width space
            "\u200C",  # Zero-width non-joiner
            "\u200D",  # Zero-width joiner
            "\uFEFF",  # Byte order mark / zero-width no-break space
            "\u0301",  # Combining acute accent (é = e + ́)
            "\u0302",  # Combining circumflex
            "\u0303",  # Combining tilde
            "\u0308",  # Combining diaeresis (ü = u + ̈)
            "\u0327",  # Combining cedilla
            "\u0338",  # Combining long solidus overlay
        ]

        # RTL and complex scripts
        self.complex_script_chars = [
            # Arabic
            "ا", "ب", "ت", "ث", "ج", "ح", "خ", "د", "ذ", "ر",
            # Hebrew
            "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט", "י",
            # Thai
            "ก", "ข", "ค", "ง", "จ", "ฉ", "ช", "ซ", "ญ", "ด",
            # Devanagari (Hindi)
            "अ", "आ", "इ", "ई", "उ", "ऊ", "ए", "ऐ", "ओ", "औ",
            # Tamil
            "அ", "ஆ", "இ", "ஈ", "உ", "ஊ", "எ", "ஏ", "ஐ", "ஒ",
        ]

        # Mathematical and technical symbols
        self.math_symbols = [
            "∀", "∃", "∄", "∅", "∈", "∉", "∋", "∌", "∏", "∑",
            "√", "∛", "∜", "∝", "∞", "∠", "∡", "∢", "∧", "∨",
            "∩", "∪", "∫", "∬", "∭", "∮", "∯", "∰", "∱", "∲",
            "≈", "≠", "≡", "≢", "≤", "≥", "≦", "≧", "≨", "≩",
            "⊂", "⊃", "⊄", "⊅", "⊆", "⊇", "⊈", "⊉", "⊊", "⊋",
        ]

        # Complex Emoji ZWJ Sequences (Family, Professions, Flags)
        # These test multi-codepoint grapheme cluster handling
        self.complex_emoji = [
            # Family: Man, Woman, Girl, Boy
            "👨‍👩‍👧‍👦", "👨‍👨‍👧‍👦", "👩‍👩‍👧‍👦", 
            # Professions (Person + ZWJ + Object)
            "👨‍⚕️", "👩‍⚖️", "👨‍✈️", "👩‍🚀", "👮‍♂️", "👮‍♀️",
            # Flags (Regional Indicator Symbols)
            "🇺🇸", "🇬🇧", "🇯🇵", "🇰🇷", "🇩🇪", "🇫🇷", "🏳️‍🌈", "🏳️‍⚧️",
            # Skin tone modifiers
            "👍🏻", "👍🏼", "👍🏽", "👍🏾", "👍🏿",
            "🧛🏻‍♂️", "🧜🏾‍♀️", "🙅🏿‍♂️",
        ]

        # Control characters (C0 and C1) that shouldn't crash the editor
        self.control_chars = [
            "\x00", "\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07",
            "\x0b", "\x0c", "\x0e", "\x0f", "\x10", "\x11", "\x12", "\x13",
            "\x14", "\x15", "\x16", "\x17", "\x18", "\x19", "\x1a", "\x1b",
            "\x1c", "\x1d", "\x1e", "\x1f", "\x7f",
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

            if choice < 0.55:  # 55% regular characters
                sequence.append(
                    random.choice(
                        string.ascii_letters + string.digits + string.punctuation + " "
                    )
                )
            elif choice < 0.70 and self.config.include_special_keys:  # 15% special keys
                sequence.append(random.choice(self.special_keys))
            elif choice < 0.95 and self.config.include_unicode:  # 25% unicode (expanded)
                unicode_choice = random.random()
                if unicode_choice < 0.20:
                    sequence.append(random.choice(self.wide_chars))
                elif unicode_choice < 0.35:
                    sequence.append(random.choice(self.exotic_chars))
                elif unicode_choice < 0.45:
                    sequence.append(random.choice(self.unicode_chars))
                elif unicode_choice < 0.55:
                    sequence.append(random.choice(self.complex_script_chars))
                elif unicode_choice < 0.65:
                    sequence.append(random.choice(self.math_symbols))
                elif unicode_choice < 0.80:
                    sequence.append(random.choice(self.complex_emoji))
                elif unicode_choice < 0.90:
                    sequence.append(random.choice(self.zero_width_chars))
                else:
                    # Control characters (use sparingly)
                    sequence.append(random.choice(self.control_chars))
            else:  # 5% escape sequences
                sequence.append(f"<ESC>{random.choice('hjkl')}")

        return "".join(sequence)

    def generate_unicode_sequence(self, length: int = 50) -> str:
        """Generate a sequence heavily focused on Unicode complexity."""
        sequence = ["i"]  # Enter insert mode
        
        categories = [
            self.wide_chars,
            self.exotic_chars,
            self.complex_script_chars,
            self.complex_emoji,
            self.math_symbols,
            self.zero_width_chars
        ]
        
        for _ in range(length):
            category = random.choice(categories)
            sequence.append(random.choice(category))
            
            # Occasionally add a space or newline to break things up
            if random.random() < 0.1:
                sequence.append(random.choice([" ", "\n"]))
                
        sequence.append("<ESC>")
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

        # Unicode stress (limited to ASCII-safe chars)
        sequences.append("".join([c for c in self.unicode_chars * 5 if ord(c) < 256]))

        # Special key combinations
        sequences.append("<C-a><C-c><C-v><C-x>" * 10)

        # --- BUG REGRESSION TESTS ---
        
        # 1. Fixed Emoji Bug: ZWJ Sequence handling
        # This tests if backspacing through a ZWJ sequence works correctly (should delete whole grapheme or not crash)
        # and if cursor positioning is correct around wide characters.
        sequences.append("i" + "👨‍👩‍👧‍👦" * 5 + "<ESC>" + "0" + "x" * 5) # Delete from start
        sequences.append("i" + "🏳️‍🌈" * 5 + "<ESC>" + "$" + "X" * 5) # Delete from end
        
        # 2. Obscure Unicode / RTL Mixing
        # Tests mixing RTL (Arabic) with LTR and Emojis
        sequences.append("i" + "Hello " + "مرحبا" + " 🌍 " + "World" + "<ESC>")
        
        # 3. Zero-width joiner stress
        # Repeated ZWJ characters can cause rendering loops or buffer issues
        sequences.append("i" + "\u200d" * 20 + "A" + "<ESC>")

        return sequences

    def generate_behavior_tests(self) -> List[BehaviorTest]:
        """Generate tests for expected editor behavior (non-standard behavior detection)."""
        tests = []

        # Test 1: Ctrl+C should NOT cause exit
        # This is the most common non-standard behavior - terminals traditionally
        # use Ctrl+C for interrupt, but in raw mode editors should handle it
        tests.append(BehaviorTest(
            name="ctrl_c_no_exit",
            sequence="<C-c>",
            should_exit=False,
            description="Ctrl+C should not exit the editor (common terminal copy key)"
        ))

        # Test 2: Multiple Ctrl+C should NOT cause exit
        tests.append(BehaviorTest(
            name="ctrl_c_repeated",
            sequence="<C-c><C-c><C-c>",
            should_exit=False,
            description="Repeated Ctrl+C should not exit the editor"
        ))

        # Test 3: Ctrl+Shift+C equivalent (same byte as Ctrl+C in terminals)
        tests.append(BehaviorTest(
            name="ctrl_shift_c_equivalent",
            sequence="<C-c>",  # Shift doesn't change control codes at byte level
            should_exit=False,
            description="Ctrl+Shift+C (copy) should not exit the editor"
        ))

        # Test 4: Standard navigation keys should not exit
        for key in ["<Up>", "<Down>", "<Left>", "<Right>", "<Home>", "<End>", "<PageUp>", "<PageDown>"]:
            tests.append(BehaviorTest(
                name=f"nav_{key.strip('<>').lower()}_no_exit",
                sequence=key,
                should_exit=False,
                description=f"{key} navigation key should not exit the editor"
            ))

        # Test 5: Ctrl key combinations that should never exit
        safe_ctrl_keys = ["a", "b", "d", "f", "g", "l", "n", "p", "r", "u", "v", "x", "z"]
        for char in safe_ctrl_keys:
            tests.append(BehaviorTest(
                name=f"ctrl_{char}_no_exit",
                sequence=f"<C-{char}>",
                should_exit=False,
                description=f"Ctrl+{char.upper()} should not exit the editor"
            ))

        # Test 6: Basic editing keys should not exit
        for key in ["<BS>", "<Delete>", "<Tab>", "<Space>", "<ESC>"]:
            tests.append(BehaviorTest(
                name=f"edit_{key.strip('<>').lower()}_no_exit",
                sequence=key,
                should_exit=False,
                description=f"{key} should not exit the editor"
            ))

        # Test 7: Normal mode movement followed by navigation
        tests.append(BehaviorTest(
            name="movement_sequence_no_exit",
            sequence="hjkl<C-c>hjkl",
            should_exit=False,
            description="Movement with Ctrl+C mixed in should not exit"
        ))

        # Test 8: Insert mode with Ctrl+C should not exit (should return to normal)
        tests.append(BehaviorTest(
            name="insert_ctrl_c_no_exit",
            sequence="i<C-c>",
            should_exit=False,
            description="Ctrl+C in insert mode should not exit (should just exit insert mode)"
        ))

        # Test 9: Visual mode with Ctrl+C should not exit
        tests.append(BehaviorTest(
            name="visual_ctrl_c_no_exit",
            sequence="v<C-c>",
            should_exit=False,
            description="Ctrl+C in visual mode should not exit (should clear selection)"
        ))

        # Test 10: Command mode with Ctrl+C should not exit
        tests.append(BehaviorTest(
            name="command_ctrl_c_no_exit",
            sequence=":<C-c>",
            should_exit=False,
            description="Ctrl+C in command mode should not exit (should cancel command)"
        ))

        return tests

    def generate_exit_verification_tests(self) -> List[BehaviorTest]:
        """Generate tests that verify exit commands work correctly.

        These are separate from behavior tests because they test positive behavior
        (things that SHOULD cause exit) rather than negative behavior detection
        (things that should NOT cause exit).
        """
        tests = []

        tests.append(BehaviorTest(
            name="quit_command_exits",
            sequence="<ESC>:q!<CR>",
            should_exit=True,
            description=":q! command should exit the editor"
        ))

        tests.append(BehaviorTest(
            name="zq_exits",
            sequence="<ESC>ZQ",
            should_exit=True,
            description="ZQ should exit the editor without saving"
        ))

        tests.append(BehaviorTest(
            name="zz_exits",
            sequence="<ESC>ZZ",
            should_exit=True,
            description="ZZ should save and exit the editor"
        ))

        return tests

    def generate_non_standard_sequences(self) -> List[str]:
        """Generate sequences specifically designed to catch non-standard behavior."""
        sequences = []

        # Focus on keys that commonly cause issues
        # Ctrl+C variations
        sequences.append("<C-c>")
        sequences.append("<C-c><C-c><C-c>")
        sequences.append("i<C-c>")  # Ctrl+C in insert mode
        sequences.append("v<C-c>")  # Ctrl+C in visual mode
        sequences.append(":<C-c>")  # Ctrl+C in command mode

        # Other Ctrl combinations that might not be handled
        for char in "abcdefghijklmnopqrstuvwxyz":
            sequences.append(f"<C-{char}>")

        # Ctrl+Shift combinations (same bytes as Ctrl in most terminals)
        # These test that the editor handles the byte value correctly
        sequences.append("<C-c>")  # Same as Ctrl+Shift+C at byte level

        # Rapid mode switching with Ctrl+C
        sequences.append("i<ESC>v<ESC><C-c>i<ESC>")

        # Mixed with commands
        sequences.append("dd<C-c>yy<C-c>p<C-c>")

        return sequences

    def generate_stress_sequences(self) -> List[str]:
        """Generate high-stress sequences that push editor limits."""
        sequences = []

        # Extreme rapid movements
        sequences.append("h" * 200)  # Very long horizontal movement
        sequences.append("j" * 200)  # Very long vertical movement
        sequences.append("l" * 200)
        sequences.append("k" * 200)

        # Rapid mode switching
        sequences.append("i" + "a" * 50 + "<ESC>" + "o" + "a" * 50 + "<ESC>")
        sequences.append("i" + "<BS>" * 20 + "<ESC>")
        sequences.append("i" + "<Delete>" * 20 + "<ESC>")

        # Command mode stress
        sequences.append(":" + "1" * 100 + "<CR>")
        sequences.append(":" + "x" * 100 + "<CR>")
        sequences.append(":" * 20 + "<CR>")

        # Visual mode stress
        sequences.append("v" + "l" * 100 + "d")
        sequences.append("V" + "j" * 50 + "d")
        sequences.append("<C-v>" + "j" * 20 + "l" * 20 + "d")

        # Search and replace stress
        sequences.append("/" + "a" * 50 + "<CR>")
        sequences.append(":" + "%s" + "/" + "a" * 20 + "/" + "b" * 20 + "/g<CR>")

        # Register stress
        sequences.append('"ayy' * 50)
        sequences.append('"ap' * 50)

        # Undo/redo stress
        sequences.append("iHello<ESC>ui<ESC>ui<ESC>ui<ESC>" * 20)
        sequences.append("iHello<ESC>ui" * 30)

        # File operations stress
        sequences.append(":w<CR>" * 10)
        sequences.append(":e!<CR>")
        sequences.append(":q!<CR>")

        # Macro stress
        sequences.append("qaHello<ESC>q" + "@a" * 20)
        sequences.append("qa" + "ia" + "<ESC>" + "q@a" * 10)

        # Navigation stress
        sequences.append("ggGggGggGggG" * 10)
        sequences.append("0$" * 50)
        sequences.append("^$" * 50)

        # Window stress
        sequences.append("<C-w>h<C-w>j<C-w>k<C-w>l" * 10)
        sequences.append("<C-w>s<C-w>v<C-w>q<C-w>q" * 5)

        # Buffer stress
        sequences.append(":bn<CR>:bp<CR>" * 20)
        sequences.append(":bfirst<CR>:blast<CR>" * 10)

        # Command history stress
        sequences.append(":" + "<Up>" * 20 + "<CR>")
        sequences.append(":" + "<Down>" * 20 + "<CR>")

        # Insert mode Unicode stress (safe chars only)
        safe_extended = [c for c in self.unicode_chars if ord(c) < 256]
        sequences.append("i" + "".join(safe_extended * 10) + "<ESC>")

        # Search stress
        sequences.append("/" + ".*.*.*" + "<CR>n" * 20)
        sequences.append("?" + ".*.*.*" + "<CR>n" * 20)

        # Emoji / Unicode Stress
        # Heavy use of complex emojis
        sequences.append("i" + "".join(self.complex_emoji * 5) + "<ESC>")
        # Mixed wide/narrow/combining
        sequences.append("i" + "a" + "\u0301" * 10 + "b" + "😀" + "c" + "👨‍👩‍👧‍👦" + "<ESC>")
        # ZWJ sequence soup
        sequences.append("i" + ("\u200d" + "😀") * 50 + "<ESC>")

        return sequences


@dataclass
class FuzzResult:
    """Result of a fuzzing run."""

    sequence: str
    success: bool
    error: str | None = None
    execution_time: float = 0.0
    output: str = ""
    unexpected_exit: bool = False  # True if editor exited when it shouldn't have
    behavior_violation: Optional[BehaviorViolation] = None


class FuzzRunner:
    """Runs fuzzing tests against editor drivers."""

    def __init__(self, driver_class, debug: bool = False):
        self.driver_class = driver_class
        self.debug = debug
        self.results: List[FuzzResult] = []
        self.behavior_results: List[BehaviorResult] = []

    def _check_process_alive(self, driver) -> bool:
        """Check if the editor process is still running."""
        import os
        if driver.child_pid is None:
            return False
        try:
            # os.kill with signal 0 checks if process exists
            os.kill(driver.child_pid, 0)
            return True
        except ProcessLookupError:
            return False
        except OSError:
            return False

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

            # Check if process is still alive before attempting quit
            if not self._check_process_alive(driver):
                result.success = False
                result.unexpected_exit = True
                result.behavior_violation = BehaviorViolation.UNEXPECTED_EXIT
                result.error = "Editor exited unexpectedly during sequence"
                result.execution_time = time.perf_counter() - start_time
                if self.debug:
                    print(f"UNEXPECTED EXIT detected for sequence: {repr(sequence[:30])}")
                return result

            # Quit
            quit_time = driver.quit()

            result.success = True
            result.execution_time = time.perf_counter() - start_time + quit_time

        except Exception as e:
            result.success = False
            result.error = str(e)
            if self.debug:
                print(f"Error in sequence: {e}")

            # Check if this was an unexpected exit
            if "exited" in str(e).lower() or not self._check_process_alive(driver):
                result.unexpected_exit = True
                result.behavior_violation = BehaviorViolation.UNEXPECTED_EXIT

            # Force quit on error
            try:
                driver.quit(force=True)
            except:
                pass

        return result

    def run_behavior_test(self, test: BehaviorTest, file_path: str | None = None) -> BehaviorResult:
        """Run a single behavior test to detect non-standard behavior."""
        import time
        import os
        driver = self.driver_class()
        result = BehaviorResult(test=test, passed=False)

        try:
            start_time = time.perf_counter()

            # Start editor
            driver.start(file_path)

            if self.debug:
                print(f"Behavior test '{test.name}': {test.description}")

            # Send the test sequence
            driver.send_keys(test.sequence, delay=0.005)

            # For tests that expect exit, wait longer and check more thoroughly
            if test.should_exit:
                # Wait for process to potentially exit
                max_wait = 1.0
                check_interval = 0.05
                waited = 0.0
                process_exited = False

                while waited < max_wait:
                    time.sleep(check_interval)
                    waited += check_interval
                    # Try to read output (this can detect closed PTY)
                    try:
                        driver.read_output(timeout=0.01)
                    except:
                        pass
                    # Check if process exited
                    if not self._check_process_alive(driver):
                        process_exited = True
                        break
                    # Also check via waitpid with WNOHANG
                    if driver.child_pid:
                        try:
                            pid, status = os.waitpid(driver.child_pid, os.WNOHANG)
                            if pid == driver.child_pid:
                                process_exited = True
                                break
                        except ChildProcessError:
                            process_exited = True
                            break
                        except:
                            pass

                result.process_exited = process_exited
                result.passed = process_exited
                if not result.passed:
                    result.violation = BehaviorViolation.STANDARD_KEY_MISBEHAVIOR
                    result.error = f"Expected exit but editor is still running"
            else:
                # For tests that expect NO exit, a quick check is sufficient
                time.sleep(0.1)
                driver.read_output(timeout=0.1)

                process_alive = self._check_process_alive(driver)
                result.process_exited = not process_alive
                result.passed = process_alive
                if not result.passed:
                    result.violation = BehaviorViolation.UNEXPECTED_EXIT
                    result.error = f"Editor exited unexpectedly (sequence: {repr(test.sequence)})"

            result.execution_time = time.perf_counter() - start_time

            # Clean up - quit if still running
            if self._check_process_alive(driver):
                try:
                    driver.quit(force=True)
                except:
                    pass

        except Exception as e:
            result.passed = False
            result.error = str(e)
            result.violation = BehaviorViolation.CRASH
            if self.debug:
                print(f"Behavior test error: {e}")
            try:
                driver.quit(force=True)
            except:
                pass

        return result

    def run_behavior_suite(self, file_path: str | None = None) -> List[BehaviorResult]:
        """Run all behavior tests to detect non-standard behavior."""
        fuzzer = InputFuzzer()
        tests = fuzzer.generate_behavior_tests()
        results = []

        print(f"\n{'='*60}")
        print("NON-STANDARD BEHAVIOR DETECTION SUITE")
        print(f"{'='*60}")
        print(f"Running {len(tests)} behavior tests...\n")

        passed = 0
        failed = 0

        for test in tests:
            result = self.run_behavior_test(test, file_path)
            results.append(result)

            status = "✓ PASS" if result.passed else "✗ FAIL"
            if result.passed:
                passed += 1
            else:
                failed += 1

            print(f"  {status} - {test.name}")
            if not result.passed and self.debug:
                print(f"         {test.description}")
                print(f"         Error: {result.error}")
                if result.violation:
                    print(f"         Violation: {result.violation.name}")

        print(f"\n{'='*60}")
        print(f"BEHAVIOR TEST RESULTS: {passed} passed, {failed} failed")
        if failed > 0:
            print("\nFAILED TESTS (non-standard behavior detected):")
            for r in results:
                if not r.passed:
                    print(f"  - {r.test.name}: {r.error}")
        print(f"{'='*60}\n")

        self.behavior_results.extend(results)
        return results

    def run_non_standard_detection(self, file_path: str | None = None) -> List[FuzzResult]:
        """Run sequences specifically designed to detect non-standard behavior."""
        fuzzer = InputFuzzer()
        sequences = fuzzer.generate_non_standard_sequences()
        results = []

        print(f"\n{'='*60}")
        print("NON-STANDARD BEHAVIOR SEQUENCE TESTS")
        print(f"{'='*60}")
        print(f"Testing {len(sequences)} potentially problematic sequences...\n")

        violations = []

        for i, sequence in enumerate(sequences, 1):
            result = self.run_sequence(sequence, file_path)
            results.append(result)

            if result.unexpected_exit:
                violations.append((sequence, result))
                print(f"  ✗ VIOLATION #{len(violations)}: Unexpected exit on {repr(sequence[:40])}")
            elif self.debug:
                print(f"  ✓ OK: {repr(sequence[:40])}")

        print(f"\n{'='*60}")
        if violations:
            print(f"NON-STANDARD BEHAVIOR DETECTED: {len(violations)} violations")
            print("\nProblematic sequences that caused unexpected exits:")
            for seq, res in violations:
                print(f"  - {repr(seq)}")
        else:
            print("All sequences handled correctly (no unexpected exits)")
        print(f"{'='*60}\n")

        self.results.extend(results)
        return results

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

    def run_stress_suite(self) -> List[FuzzResult]:
        """Run stress test sequences."""
        fuzzer = InputFuzzer()
        stress_sequences = fuzzer.generate_stress_sequences()
        results = []

        print(f"Running {len(stress_sequences)} stress test scenarios...")

        for i, sequence in enumerate(stress_sequences, 1):
            print(
                f"Test {i}/{len(stress_sequences)}: {repr(sequence[:30])}{'...' if len(sequence) > 30 else ''}"
            )
            result = self.run_sequence(sequence)
            results.append(result)

            status = "✓ PASS" if result.success else "✗ FAIL"
            print(f"  {status} ({result.execution_time:.3f}s)")

            if not result.success and self.debug:
                print(f"  Error: {result.error}")

        return results

    def get_summary(self) -> Dict[str, Any]:
        """Get summary statistics of fuzzing results."""
        summary = {}

        if self.results:
            total = len(self.results)
            successful = sum(1 for r in self.results if r.success)
            failed = total - successful
            unexpected_exits = sum(1 for r in self.results if r.unexpected_exit)

            errors = {}
            for result in self.results:
                if not result.success and result.error:
                    errors[result.error] = errors.get(result.error, 0) + 1

            avg_time = sum(r.execution_time for r in self.results) / total

            summary["fuzz_results"] = {
                "total_sequences": total,
                "successful": successful,
                "failed": failed,
                "success_rate": successful / total,
                "unexpected_exits": unexpected_exits,
                "average_execution_time": avg_time,
                "error_distribution": errors,
            }

        if self.behavior_results:
            behavior_total = len(self.behavior_results)
            behavior_passed = sum(1 for r in self.behavior_results if r.passed)
            behavior_failed = behavior_total - behavior_passed

            violations_by_type = {}
            for result in self.behavior_results:
                if result.violation:
                    v_name = result.violation.name
                    violations_by_type[v_name] = violations_by_type.get(v_name, 0) + 1

            summary["behavior_results"] = {
                "total_tests": behavior_total,
                "passed": behavior_passed,
                "failed": behavior_failed,
                "pass_rate": behavior_passed / behavior_total if behavior_total > 0 else 0,
                "violations_by_type": violations_by_type,
                "failed_tests": [
                    {
                        "name": r.test.name,
                        "description": r.test.description,
                        "error": r.error,
                        "violation": r.violation.name if r.violation else None,
                    }
                    for r in self.behavior_results
                    if not r.passed
                ],
            }

        return summary
