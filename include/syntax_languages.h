#ifndef SYNTAX_LANGUAGES_H
#define SYNTAX_LANGUAGES_H

// Language Definitions ported from legacy/swift/Sources/videre/Syntax/Languages.swift

// --- C ---
static char *C_EXTS[] = { ".c", ".h", NULL };
static char *C_KEYWORDS[] = {
    "auto", "break", "case", "char", "const", "continue", "default", "do",
    "double", "else", "enum", "extern", "float", "for", "goto", "if",
    "inline", "int", "long", "register", "restrict", "return", "short",
    "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
    "unsigned", "void", "volatile", "while", "_Alignas", "_Alignof",
    "_Atomic", "_Bool", "_Complex", "_Generic", "_Imaginary", "_Noreturn",
    "_Static_assert", "_Thread_local", 
    "int|", "char|", "float|", "double|", "void|", "long|", "short|", "unsigned|",
    "signed|", "size_t|", "ptrdiff_t|", "int8_t|", "int16_t|", "int32_t|",
    "int64_t|", "uint8_t|", "uint16_t|", "uint32_t|", "uint64_t|", "bool|",
    "FILE|", "wchar_t|",
    "NULL", "EOF", "true", "false", "stdin", "stdout", "stderr",
    NULL
};

// --- C++ ---
static char *CPP_EXTS[] = { ".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx", NULL };
static char *CPP_KEYWORDS[] = {
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
    "using", "virtual", "void", "volatile", "wchar_t", "while", "xor",
    "xor_eq", "override", "final",
    "int|", "char|", "float|", "double|", "void|", "long|", "short|", "unsigned|",
    "signed|", "bool|", "wchar_t|", "size_t|", "string|", "vector|", "map|",
    "set|", "list|", "deque|", "array|", "pair|", "tuple|", "optional|",
    "variant|", "any|", "shared_ptr|", "unique_ptr|", "weak_ptr|",
    "NULL", "nullptr", "true", "false", "EOF",
    NULL
};

// --- Objective-C ---
static char *OBJC_EXTS[] = { ".m", ".mm", NULL };
static char *OBJC_KEYWORDS[] = {
    "@interface", "@implementation", "@end", "@class", "@protocol",
    "@required", "@optional", "@property", "@synthesize", "@dynamic",
    "@selector", "@encode", "@synchronized", "@try", "@catch", "@finally",
    "@throw", "@autoreleasepool", "self", "super", "nil", "Nil", "YES",
    "NO", "id", "instancetype", "SEL", "IMP", "Class", "BOOL",
    "NSObject|", "NSString|", "NSArray|", "NSDictionary|", "NSNumber|", "NSInteger|",
    "NSUInteger|", "CGFloat|",
    NULL
};

// --- Swift ---
static char *SWIFT_EXTS[] = { ".swift", NULL };
static char *SWIFT_KEYWORDS[] = {
    "actor", "any", "as", "associatedtype", "async", "await", "break",
    "case", "catch", "class", "continue", "convenience", "default",
    "defer", "deinit", "didSet", "do", "dynamic", "else", "enum",
    "extension", "fallthrough", "false", "fileprivate", "final", "for",
    "func", "get", "guard", "if", "import", "in", "indirect", "infix",
    "init", "inout", "internal", "is", "isolated", "lazy", "let",
    "mutating", "nil", "nonisolated", "nonmutating", "open", "operator",
    "optional", "override", "postfix", "precedencegroup", "prefix",
    "private", "protocol", "public", "repeat", "required", "rethrows",
    "return", "self", "Self", "set", "some", "static", "struct",
    "subscript", "super", "switch", "throw", "throws", "true", "try",
    "typealias", "unowned", "var", "weak", "where", "while", "willSet",
    "Int|", "Int8|", "Int16|", "Int32|", "Int64|", "UInt|", "UInt8|", "UInt16|",
    "UInt32|", "UInt64|", "Float|", "Double|", "Bool|", "String|", "Character|",
    "Array|", "Dictionary|", "Set|", "Optional|", "Result|", "Void|", "Never|",
    "Any|", "AnyObject|", "Error|", "View|", "Data|", "URL|", "Date|", "UUID|",
    "true", "false", "nil",
    NULL
};

// --- Python ---
static char *PY_EXTS[] = { ".py", ".pyw", ".pyi", NULL };
static char *PY_KEYWORDS[] = {
    "False", "None", "True", "and", "as", "assert", "async", "await",
    "break", "class", "continue", "def", "del", "elif", "else", "except",
    "finally", "for", "from", "global", "if", "import", "in", "is",
    "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try",
    "while", "with", "yield", "match", "case",
    "int|", "float|", "complex|", "bool|", "str|", "bytes|", "bytearray|",
    "list|", "tuple|", "range|", "dict|", "set|", "frozenset|", "type|",
    "object|", "Exception|", "BaseException|",
    "self", "cls", "__init__", "__str__", "__repr__", "__name__", "__main__",
    NULL
};

// --- Rust ---
static char *RS_EXTS[] = { ".rs", NULL };
static char *RS_KEYWORDS[] = {
    "as", "async", "await", "break", "const", "continue", "crate", "dyn",
    "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
    "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
    "self", "Self", "static", "struct", "super", "trait", "true", "type",
    "unsafe", "use", "where", "while",
    "bool|", "char|", "f32|", "f64|", "i8|", "i16|", "i32|", "i64|", "i128|",
    "isize|", "str|", "u8|", "u16|", "u32|", "u64|", "u128|", "usize|", "String|",
    "Vec|", "Box|", "Rc|", "Arc|", "Cell|", "RefCell|", "Option|", "Result|",
    "HashMap|", "HashSet|", "BTreeMap|", "BTreeSet|",
    NULL
};

// --- Go ---
static char *GO_EXTS[] = { ".go", NULL };
static char *GO_KEYWORDS[] = {
    "break", "case", "chan", "const", "continue", "default", "defer",
    "else", "fallthrough", "for", "func", "go", "goto", "if", "import",
    "interface", "map", "package", "range", "return", "select", "struct",
    "switch", "type", "var",
    "bool|", "byte|", "complex64|", "complex128|", "error|", "float32|",
    "float64|", "int|", "int8|", "int16|", "int32|", "int64|", "rune|", "string|",
    "uint|", "uint8|", "uint16|", "uint32|", "uint64|", "uintptr|", "any|",
    "true", "false", "nil", "iota",
    NULL
};

// --- JavaScript/TypeScript ---
static char *JS_EXTS[] = { ".js", ".mjs", ".cjs", ".jsx", ".ts", ".tsx", NULL };
static char *JS_KEYWORDS[] = {
    "async", "await", "break", "case", "catch", "class", "const",
    "continue", "debugger", "default", "delete", "do", "else", "export",
    "extends", "false", "finally", "for", "function", "if", "import",
    "in", "instanceof", "let", "new", "null", "of", "return", "static",
    "super", "switch", "this", "throw", "true", "try", "typeof", "var",
    "void", "while", "with", "yield", "get", "set",
    "abstract", "as", "asserts", "declare", "enum", "implements",
    "interface", "infer", "is", "keyof", "module", "namespace", "never",
    "override", "readonly", "type", "unknown", "any", "private",
    "protected", "public",
    "Array|", "Boolean|", "Date|", "Error|", "Function|", "JSON|", "Map|",
    "Math|", "Number|", "Object|", "Promise|", "Proxy|", "RegExp|", "Set|",
    "String|", "Symbol|", "WeakMap|", "WeakSet|", "BigInt|", "ArrayBuffer|",
    "DataView|", "Float32Array|", "Float64Array|", "Int8Array|", "Int16Array|",
    "Int32Array|", "Uint8Array|", "Uint16Array|", "Uint32Array|",
    "true", "false", "null", "undefined", "NaN", "Infinity",
    NULL
};

// --- Java ---
static char *JAVA_EXTS[] = { ".java", NULL };
static char *JAVA_KEYWORDS[] = {
    "abstract", "assert", "boolean", "break", "byte", "case", "catch",
    "char", "class", "const", "continue", "default", "do", "double",
    "else", "enum", "extends", "final", "finally", "float", "for",
    "goto", "if", "implements", "import", "instanceof", "int",
    "interface", "long", "native", "new", "package", "private",
    "protected", "public", "return", "short", "static", "strictfp",
    "super", "switch", "synchronized", "this", "throw", "throws",
    "transient", "try", "var", "void", "volatile", "while", "record",
    "sealed", "permits", "yield",
    "Boolean|", "Byte|", "Character|", "Double|", "Float|", "Integer|",
    "Long|", "Short|", "String|", "Object|", "Class|", "Void|", "Number|",
    "List|", "ArrayList|", "Map|", "HashMap|", "Set|", "HashSet|",
    "true", "false", "null",
    NULL
};

// --- Ruby ---
static char *RUBY_EXTS[] = { ".rb", ".rake", "gemspec", NULL };
static char *RUBY_KEYWORDS[] = {
    "BEGIN", "END", "alias", "and", "begin", "break", "case", "class",
    "def", "defined?", "do", "else", "elsif", "end", "ensure", "false",
    "for", "if", "in", "module", "next", "nil", "not", "or", "redo",
    "rescue", "retry", "return", "self", "super", "then", "true",
    "undef", "unless", "until", "when", "while", "yield",
    "String|", "Integer|", "Float|", "Array|", "Hash|", "Symbol|", "Regexp|",
    "Range|", "Proc|", "Lambda|", "Method|", "Class|", "Module|", "Object|",
    "true", "false", "nil",
    NULL
};

// --- Shell ---
static char *SH_EXTS[] = { ".sh", ".bash", ".zsh", ".fish", NULL };
static char *SH_KEYWORDS[] = {
    "if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
    "until", "do", "done", "in", "function", "select", "time", "coproc",
    "return", "exit", "break", "continue", "local", "declare", "typeset",
    "export", "readonly", "unset", "shift", "source", "alias", "unalias",
    "set", "eval", "exec", "trap",
    "true", "false",
    NULL
};

// --- Lua ---
static char *LUA_EXTS[] = { ".lua", NULL };
static char *LUA_KEYWORDS[] = {
    "and", "break", "do", "else", "elseif", "end", "false", "for",
    "function", "goto", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
    "true", "false", "nil",
    NULL
};

// --- Markdown ---
static char *MD_EXTS[] = { ".md", ".markdown", NULL };
static char *MD_KEYWORDS[] = { NULL };

// --- SQL ---
static char *SQL_EXTS[] = { ".sql", NULL };
static char *SQL_KEYWORDS[] = {
    "ADD", "ALL", "ALTER", "AND", "AS", "ASC", "BETWEEN", "BY", "CASE",
    "CHECK", "COLUMN", "CONSTRAINT", "CREATE", "DATABASE", "DEFAULT",
    "DELETE", "DESC", "DISTINCT", "DROP", "ELSE", "END", "EXISTS",
    "FOREIGN", "FROM", "FULL", "GROUP", "HAVING", "IF", "IN", "INDEX",
    "INNER", "INSERT", "INTO", "IS", "JOIN", "KEY", "LEFT", "LIKE",
    "LIMIT", "NOT", "NULL", "ON", "OR", "ORDER", "OUTER", "PRIMARY",
    "REFERENCES", "RIGHT", "SELECT", "SET", "TABLE", "THEN", "TOP",
    "TRUNCATE", "UNION", "UNIQUE", "UPDATE", "VALUES", "VIEW", "WHEN",
    "WHERE", "WITH",
    "INT|", "INTEGER|", "BIGINT|", "SMALLINT|", "TINYINT|", "FLOAT|", "DOUBLE|",
    "DECIMAL|", "NUMERIC|", "CHAR|", "VARCHAR|", "TEXT|", "BLOB|", "DATE|",
    "TIME|", "DATETIME|", "TIMESTAMP|", "BOOLEAN|", "BOOL|", "SERIAL|",
    "TRUE", "FALSE", "NULL",
    NULL
};

// --- Makefile ---
static char *MAKE_EXTS[] = { "Makefile", "makefile", ".mk", ".mak", NULL };
static char *MAKE_KEYWORDS[] = {
    "define", "endef", "undefine", "ifdef", "ifndef", "ifeq", "ifneq",
    "else", "endif", "include", "sinclude", "override", "export",
    "unexport", "private", "vpath",
    NULL
};

// --- PHP ---
static char *PHP_EXTS[] = { ".php", ".phtml", NULL };
static char *PHP_KEYWORDS[] = {
    "abstract", "and", "as", "break", "callable", "case", "catch",
    "class", "clone", "const", "continue", "declare", "default", "do",
    "echo", "else", "elseif", "empty", "enddeclare", "endfor",
    "endforeach", "endif", "endswitch", "endwhile", "extends", "final",
    "finally", "fn", "for", "foreach", "function", "global", "goto",
    "if", "implements", "include", "include_once", "instanceof",
    "insteadof", "interface", "isset", "list", "match", "namespace",
    "new", "or", "print", "private", "protected", "public", "readonly",
    "require", "require_once", "return", "static", "switch", "throw",
    "trait", "try", "unset", "use", "var", "while", "xor", "yield",
    "array|", "bool|", "boolean|", "double|", "float|", "int|", "integer|",
    "object|", "string|", "void|",
    "true", "false", "null",
    NULL
};

// --- Zig ---
static char *ZIG_EXTS[] = { ".zig", NULL };
static char *ZIG_KEYWORDS[] = {
    "addrspace", "align", "allowzero", "and", "anyframe", "anytype",
    "asm", "async", "await", "break", "callconv", "catch", "comptime",
    "const", "continue", "defer", "else", "enum", "errdefer", "error",
    "export", "extern", "fn", "for", "if", "inline", "linksection",
    "noalias", "nosuspend", "opaque", "or", "orelse", "packed", "pub",
    "resume", "return", "struct", "suspend", "switch", "test",
    "threadlocal", "try", "union", "unreachable", "usingnamespace",
    "var", "volatile", "while",
    "bool|", "f16|", "f32|", "f64|", "f80|", "f128|", "isize|", "usize|", "void|",
    "true", "false", "null", "undefined",
    NULL
};

// --- Assembly ---
static char *ASM_EXTS[] = { ".asm", ".s", ".S", NULL };
static char *ASM_KEYWORDS[] = {
    "section", "segment", "global", "extern", "bits", "use16", "use32",
    "use64", "default", "equ", "times", "db", "dw", "dd", "dq", "dt",
    "resb", "resw", "resd", "resq", "rest", "incbin", "align", "alignb",
    "struc", "endstruc", "istruc", "iend", "at", "macro", "endmacro",
    NULL
};

// --- HolyC ---
static char *HC_EXTS[] = { ".hc", ".HC", "holyc", NULL };
static char *HC_KEYWORDS[] = {
    "asm", "break", "case", "catch", "class", "const", "continue",
    "default", "do", "else", "extern", "false", "for", "goto", "if",
    "import", "in", "interrupt", "lastclass", "lock", "no_warn",
    "noreg", "nowarn", "public", "reg", "return", "sizeof", "static",
    "switch", "true", "try", "union", "while",
    "Bool|", "I0|", "I8|", "I16|", "I32|", "I64|", "U0|", "U8|", "U16|", "U32|",
    "U64|", "F64|",
    "TRUE", "FALSE", "NULL",
    NULL
};

#endif
