#ifndef SYNTAX_LANGUAGES_H
#define SYNTAX_LANGUAGES_H

// C/C++ Language Definitions
// Ported from legacy/swift/Sources/videre/Syntax/Languages.swift

// C Keywords
static const char *C_KEYWORDS[] = {
    "auto", "break", "case", "char", "const", "continue", "default", "do",
    "double", "else", "enum", "extern", "float", "for", "goto", "if",
    "inline", "int", "long", "register", "restrict", "return", "short",
    "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
    "unsigned", "void", "volatile", "while",
    // C11/C99 Keywords
    "_Alignas", "_Alignof", "_Atomic", "_Bool", "_Complex", "_Generic",
    "_Imaginary", "_Noreturn", "_Static_assert", "_Thread_local",
    NULL
};

// C Types
static const char *C_TYPES[] = {
    "int", "char", "float", "double", "void", "long", "short", "unsigned",
    "signed", "size_t", "ptrdiff_t", "int8_t", "int16_t", "int32_t",
    "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "bool",
    "FILE", "wchar_t",
    NULL
};

// C++ Keywords (includes all C keywords plus C++)
static const char *CPP_KEYWORDS[] = {
    "alignas", "alignof", "and", "and_eq", "asm", "auto", "bitand",
    "bitor", "bool", "break", "case", "catch", "char", "char8_t",
    "char16_t", "char32_t", "class", "compl", "concept", "const",
    "consteval", "constexpr", "constinit", "const_cast", "continue",
    "co_await", "co_return", "co_yield", "decltype", "default", "delete",
    "do", "double", "dynamic_cast", "else", "enum", "explicit", "export",
    "extern", "false", "float", "for", "friend", "goto", "if", "inline",
    "int", "long", "mutable", "namespace", "new", "noexcept", "not",
    "not_eq", "nullptr", "operator", "or", "or_eq", "private", "protected",
    "public", "register", "reinterpret_cast", "requires", "return",
    "short", "signed", "sizeof", "static", "static_assert", "static_cast",
    "struct", "switch", "template", "this", "thread_local", "throw",
    "true", "try", "typedef", "typeid", "typename", "union", "unsigned",
    "using", "virtual", "void", "volatile", "wchar_t", "while",
    "xor", "xor_eq", "override", "final",
    NULL
};

// C++ Types
static const char *CPP_TYPES[] = {
    "int", "char", "float", "double", "void", "long", "short", "unsigned",
    "signed", "bool", "wchar_t", "size_t", "string", "vector", "map",
    "set", "list", "deque", "array", "pair", "tuple", "optional",
    "variant", "any", "shared_ptr", "unique_ptr", "weak_ptr",
    NULL
};

// C/C++ Constants
static const char *C_CONSTANTS[] = {
    "NULL", "EOF", "true", "false", "stdin", "stdout", "stderr",
    "nullptr",
    NULL
};

#endif // SYNTAX_LANGUAGES_H
