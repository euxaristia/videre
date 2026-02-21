# Videre Security Testing

This document outlines the security testing setup for videre to ensure the Go version is secure and robust.

## Overview

The security testing suite includes:
- **AFL Fuzzing** - Automated vulnerability discovery
- **Static Analysis** - Code quality and security scanning
- **Memory Error Detection** - Runtime memory safety checks
- **Security Test Suite** - Targeted security tests

## Threat Model Assumptions

- Local host integrity is assumed (no active local compromise).
- The runtime environment and `PATH` are treated as trusted.
- External helper commands (`git`, `wl-copy`, `wl-paste`, `xclip`) are resolved via `PATH` by design.
- If an attacker can replace binaries in trusted lookup paths, that is considered host compromise and out of scope for Videre hardening.

## Quick Start

```bash
# Run all security tests
go test ./...

# Run race detector checks
go test -race ./...

# Run static analysis
go vet ./...
staticcheck ./...
```

## AFL Fuzzing

### Setup
```bash
mkdir -p fuzz/input fuzz/output
```
This creates:
- `fuzz/input/` - Seed files for fuzzing
- `fuzz/output/` - AFL output directory
- Various malicious seed files

### Running Fuzzing
```bash
# Single-core fuzzing
afl-fuzz -i fuzz/input -o fuzz/output -- ./fuzz/fuzz_target

# Multi-core parallel fuzzing
afl-fuzz -i fuzz/input -o fuzz/output -M fuzzer01 -- ./fuzz/fuzz_target
afl-fuzz -i fuzz/input -o fuzz/output -S fuzzer02 -- ./fuzz/fuzz_target
```

### Monitoring Progress
```bash
# View fuzzing statistics
afl-whatsup fuzz/output/

# Inspect crashes
ls -1 fuzz/output/default/crashes/
```

### Seed Files
The fuzzing includes various attack vectors:
- **Text files** - Normal content, long lines, empty files
- **Binary files** - Null bytes, high ASCII, shellcode patterns
- **Escape sequences** - ANSI escape sequences
- **Buffer overflow patterns** - Long strings, heap patterns

## Security Test Suite

### Targeted Tests
The `tests/security_tests.c` includes tests for:
- **Buffer overflows** - Long strings and heap patterns
- **Format string attacks** - Malicious format strings
- **Integer overflows** - Boundary conditions
- **Memory exhaustion** - Large allocation handling
- **File operations** - Malicious file content

### Running Security Tests
```bash
go test ./...
```

## Static Analysis

### Go Vet
```bash
go vet ./...
```

### Staticcheck
```bash
staticcheck ./...
```

## Memory Error Detection

Go's built-in race detector can be used to find data races:

```bash
go test -race ./...
```

## Continuous Integration

Add to your CI pipeline:

```yaml
security:
  script:
    - go test ./...
    - go test -race ./...
    - go vet ./...
    - staticcheck ./...
  artifacts:
    reports:
      junit: security-results.xml
```

## Vulnerability Classes Tested

### Memory Safety
Go is a memory-safe language, which automatically handles memory management and prevents common issues like:
- **Buffer overflows** - Handled by runtime bounds checking
- **Use-after-free** - Prevented by garbage collection
- **Double free** - Prevented by garbage collection
- **Memory leaks** - Managed by garbage collection

### Integer Safety
- **Integer overflows** - Arithmetic operations
- **Signed/unsigned issues** - Type conversion
- **Boundary conditions** - Edge cases

### Input Validation
- **Format strings** - Printf vulnerabilities
- **Path traversal** - File operations
- **Command injection** - System calls

### Parser Security
- **Escape sequences** - Terminal codes
- **ANSI codes** - Color/formatting
- **Unicode handling** - Text encoding

## Fuzzing Targets

### Primary Targets
- **File loading** - `editorOpen()`
- **Text insertion** - `editorInsertChar()`
- **Row operations** - `editorInsertRow()`, `editorDelRow()`
- **Search functionality** - Pattern matching
- **Syntax highlighting** - File parsing

### Attack Surface
- **File I/O** - All file operations
- **Memory allocation** - Dynamic memory management
- **String operations** - Text processing
- **Terminal handling** - Escape sequence parsing

## Crash Analysis

When AFL finds crashes:

```bash
# Analyze crash
gdb -ex 'run' -ex 'bt' -- fuzz/fuzz_target < fuzz/output/default/crashes/id:000000*

# Minimize crash case
afl-tmin -i fuzz/output/default/crashes/id:000000* -o minimized_crash -- fuzz/fuzz_target
```

## Security Best Practices

### Code Review Checklist
- [ ] All bounds checks validated
- [ ] Input sanitization implemented
- [ ] Memory allocation checked
- [ ] String operations safe
- [ ] File operations validated

### Development Guidelines
- Use safe string functions (`strncpy`, `snprintf`)
- Validate all input bounds
- Check return values of system calls
- Initialize all variables
- Use RAII patterns for memory management

## Reporting Security Issues

If you find a security vulnerability:
1. **Do not open a public issue**
2. Email: security@videre.dev
3. Include: reproduction steps, impact assessment
4. Allow 90 days before disclosure

## Compliance

This security testing helps ensure compliance with:
- **CWE Top 25** - Common weakness enumeration
- **OWASP** - Web application security
- **ISO 27001** - Information security management
- **SOC 2** - Security controls

## Performance Impact

Security testing adds minimal overhead:
- **Sanitizers**: ~2x slowdown
- **Static analysis**: Build time increase
- **Fuzzing**: Continuous background process

## Resources

- [AFL User Manual](https://github.com/google/AFL/blob/master/docs/README.md)
- [AddressSanitizer Wiki](https://github.com/google/sanitizers/wiki/AddressSanitizer)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
