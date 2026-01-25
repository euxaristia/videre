import Foundation

/// Collection of all supported language definitions
enum Languages {
    // MARK: - C Family

    static let c = LanguageDefinition(
        name: "C",
        extensions: ["c", "h"],
        keywords: [
            "auto", "break", "case", "char", "const", "continue", "default", "do",
            "double", "else", "enum", "extern", "float", "for", "goto", "if",
            "inline", "int", "long", "register", "restrict", "return", "short",
            "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
            "unsigned", "void", "volatile", "while", "_Alignas", "_Alignof",
            "_Atomic", "_Bool", "_Complex", "_Generic", "_Imaginary", "_Noreturn",
            "_Static_assert", "_Thread_local",
        ],
        types: [
            "int", "char", "float", "double", "void", "long", "short", "unsigned",
            "signed", "size_t", "ptrdiff_t", "int8_t", "int16_t", "int32_t",
            "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "bool",
            "FILE", "wchar_t",
        ],
        constants: ["NULL", "EOF", "true", "false", "stdin", "stdout", "stderr"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        preprocessorPrefix: "#"
    )

    static let cpp = LanguageDefinition(
        name: "C++",
        extensions: ["cpp", "cc", "cxx", "hpp", "hh", "hxx", "h++", "c++"],
        keywords: [
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
        ],
        types: [
            "int", "char", "float", "double", "void", "long", "short", "unsigned",
            "signed", "bool", "wchar_t", "size_t", "string", "vector", "map",
            "set", "list", "deque", "array", "pair", "tuple", "optional",
            "variant", "any", "shared_ptr", "unique_ptr", "weak_ptr",
        ],
        constants: ["NULL", "nullptr", "true", "false", "EOF"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        preprocessorPrefix: "#"
    )

    static let objc = LanguageDefinition(
        name: "Objective-C",
        extensions: ["m", "mm"],
        keywords: c.keywords.union([
            "@interface", "@implementation", "@end", "@class", "@protocol",
            "@required", "@optional", "@property", "@synthesize", "@dynamic",
            "@selector", "@encode", "@synchronized", "@try", "@catch", "@finally",
            "@throw", "@autoreleasepool", "self", "super", "nil", "Nil", "YES",
            "NO", "id", "instancetype", "SEL", "IMP", "Class", "BOOL",
        ]),
        types: c.types.union(["NSObject", "NSString", "NSArray", "NSDictionary", "NSNumber", "NSInteger", "NSUInteger", "CGFloat"]),
        constants: c.constants.union(["nil", "Nil", "YES", "NO"]),
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        preprocessorPrefix: "#"
    )

    // MARK: - Swift

    static let swift = LanguageDefinition(
        name: "Swift",
        extensions: ["swift"],
        keywords: [
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
        ],
        types: [
            "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16",
            "UInt32", "UInt64", "Float", "Double", "Bool", "String", "Character",
            "Array", "Dictionary", "Set", "Optional", "Result", "Void", "Never",
            "Any", "AnyObject", "Error", "Equatable", "Hashable", "Comparable",
            "Codable", "Encodable", "Decodable", "Identifiable", "View", "Data",
            "URL", "Date", "UUID",
        ],
        constants: ["true", "false", "nil"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\""],
        specialIdentifiers: ["#selector", "#keyPath", "#available", "#if", "#else", "#elseif", "#endif", "#warning", "#error"]
    )

    // MARK: - JavaScript/TypeScript

    static let javascript = LanguageDefinition(
        name: "JavaScript",
        extensions: ["js", "mjs", "cjs", "jsx"],
        keywords: [
            "async", "await", "break", "case", "catch", "class", "const",
            "continue", "debugger", "default", "delete", "do", "else", "export",
            "extends", "false", "finally", "for", "function", "if", "import",
            "in", "instanceof", "let", "new", "null", "of", "return", "static",
            "super", "switch", "this", "throw", "true", "try", "typeof", "var",
            "void", "while", "with", "yield", "get", "set",
        ],
        types: [
            "Array", "Boolean", "Date", "Error", "Function", "JSON", "Map",
            "Math", "Number", "Object", "Promise", "Proxy", "RegExp", "Set",
            "String", "Symbol", "WeakMap", "WeakSet", "BigInt", "ArrayBuffer",
            "DataView", "Float32Array", "Float64Array", "Int8Array", "Int16Array",
            "Int32Array", "Uint8Array", "Uint16Array", "Uint32Array",
        ],
        constants: ["true", "false", "null", "undefined", "NaN", "Infinity"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'", "`"]
    )

    static let typescript = LanguageDefinition(
        name: "TypeScript",
        extensions: ["ts", "tsx", "mts", "cts"],
        keywords: javascript.keywords.union([
            "abstract", "as", "asserts", "declare", "enum", "implements",
            "interface", "infer", "is", "keyof", "module", "namespace", "never",
            "override", "readonly", "type", "unknown", "any", "private",
            "protected", "public",
        ]),
        types: javascript.types.union([
            "any", "boolean", "never", "number", "object", "string", "symbol",
            "undefined", "unknown", "void", "Partial", "Required", "Readonly",
            "Record", "Pick", "Omit", "Exclude", "Extract", "NonNullable",
            "Parameters", "ReturnType", "InstanceType",
        ]),
        constants: javascript.constants,
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'", "`"]
    )

    // MARK: - Python

    static let python = LanguageDefinition(
        name: "Python",
        extensions: ["py", "pyw", "pyi"],
        keywords: [
            "False", "None", "True", "and", "as", "assert", "async", "await",
            "break", "class", "continue", "def", "del", "elif", "else", "except",
            "finally", "for", "from", "global", "if", "import", "in", "is",
            "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try",
            "while", "with", "yield", "match", "case",
        ],
        types: [
            "int", "float", "complex", "bool", "str", "bytes", "bytearray",
            "list", "tuple", "range", "dict", "set", "frozenset", "type",
            "object", "Exception", "BaseException", "None",
        ],
        constants: ["True", "False", "None", "Ellipsis", "NotImplemented"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"],
        specialIdentifiers: ["self", "cls", "__init__", "__str__", "__repr__", "__name__", "__main__"]
    )

    // MARK: - Rust

    static let rust = LanguageDefinition(
        name: "Rust",
        extensions: ["rs"],
        keywords: [
            "as", "async", "await", "break", "const", "continue", "crate", "dyn",
            "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
            "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
            "self", "Self", "static", "struct", "super", "trait", "true", "type",
            "unsafe", "use", "where", "while",
        ],
        types: [
            "bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "i128",
            "isize", "str", "u8", "u16", "u32", "u64", "u128", "usize", "String",
            "Vec", "Box", "Rc", "Arc", "Cell", "RefCell", "Option", "Result",
            "HashMap", "HashSet", "BTreeMap", "BTreeSet",
        ],
        constants: ["true", "false", "None", "Some", "Ok", "Err"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\""],
        specialIdentifiers: ["self", "Self", "crate", "super"]
    )

    // MARK: - Go

    static let go = LanguageDefinition(
        name: "Go",
        extensions: ["go"],
        keywords: [
            "break", "case", "chan", "const", "continue", "default", "defer",
            "else", "fallthrough", "for", "func", "go", "goto", "if", "import",
            "interface", "map", "package", "range", "return", "select", "struct",
            "switch", "type", "var",
        ],
        types: [
            "bool", "byte", "complex64", "complex128", "error", "float32",
            "float64", "int", "int8", "int16", "int32", "int64", "rune", "string",
            "uint", "uint8", "uint16", "uint32", "uint64", "uintptr", "any",
        ],
        constants: ["true", "false", "nil", "iota"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'", "`"]
    )

    // MARK: - Java

    static let java = LanguageDefinition(
        name: "Java",
        extensions: ["java"],
        keywords: [
            "abstract", "assert", "boolean", "break", "byte", "case", "catch",
            "char", "class", "const", "continue", "default", "do", "double",
            "else", "enum", "extends", "final", "finally", "float", "for",
            "goto", "if", "implements", "import", "instanceof", "int",
            "interface", "long", "native", "new", "package", "private",
            "protected", "public", "return", "short", "static", "strictfp",
            "super", "switch", "synchronized", "this", "throw", "throws",
            "transient", "try", "var", "void", "volatile", "while", "record",
            "sealed", "permits", "yield",
        ],
        types: [
            "boolean", "byte", "char", "double", "float", "int", "long", "short",
            "void", "Boolean", "Byte", "Character", "Double", "Float", "Integer",
            "Long", "Short", "String", "Object", "Class", "Void", "Number",
            "List", "ArrayList", "Map", "HashMap", "Set", "HashSet",
        ],
        constants: ["true", "false", "null"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/"
    )

    // MARK: - Ruby

    static let ruby = LanguageDefinition(
        name: "Ruby",
        extensions: ["rb", "rake", "gemspec"],
        keywords: [
            "BEGIN", "END", "alias", "and", "begin", "break", "case", "class",
            "def", "defined?", "do", "else", "elsif", "end", "ensure", "false",
            "for", "if", "in", "module", "next", "nil", "not", "or", "redo",
            "rescue", "retry", "return", "self", "super", "then", "true",
            "undef", "unless", "until", "when", "while", "yield", "__FILE__",
            "__LINE__", "__ENCODING__", "lambda", "proc", "raise", "require",
            "require_relative", "include", "extend", "prepend", "attr_reader",
            "attr_writer", "attr_accessor", "private", "protected", "public",
        ],
        types: [
            "String", "Integer", "Float", "Array", "Hash", "Symbol", "Regexp",
            "Range", "Proc", "Lambda", "Method", "Class", "Module", "Object",
            "NilClass", "TrueClass", "FalseClass", "Numeric", "Comparable",
            "Enumerable", "Enumerator", "File", "IO", "Dir", "Time", "Date",
        ],
        constants: ["true", "false", "nil", "ARGV", "ARGF", "ENV", "STDIN", "STDOUT", "STDERR"],
        lineComment: "#",
        blockCommentStart: "=begin",
        blockCommentEnd: "=end",
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - Shell/Bash

    static let shell = LanguageDefinition(
        name: "Shell",
        extensions: ["sh", "bash", "zsh", "fish", "ksh"],
        keywords: [
            "if", "then", "else", "elif", "fi", "case", "esac", "for", "while",
            "until", "do", "done", "in", "function", "select", "time", "coproc",
            "return", "exit", "break", "continue", "local", "declare", "typeset",
            "export", "readonly", "unset", "shift", "source", "alias", "unalias",
            "set", "eval", "exec", "trap",
        ],
        types: [],
        constants: ["true", "false"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - Lua

    static let lua = LanguageDefinition(
        name: "Lua",
        extensions: ["lua"],
        keywords: [
            "and", "break", "do", "else", "elseif", "end", "false", "for",
            "function", "goto", "if", "in", "local", "nil", "not", "or",
            "repeat", "return", "then", "true", "until", "while",
        ],
        types: [],
        constants: ["true", "false", "nil", "_G", "_VERSION"],
        lineComment: "--",
        blockCommentStart: "--[[",
        blockCommentEnd: "]]",
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - HTML/XML

    static let html = LanguageDefinition(
        name: "HTML",
        extensions: ["html", "htm", "xhtml"],
        keywords: [],
        types: [],
        constants: [],
        lineComment: nil,
        blockCommentStart: "<!--",
        blockCommentEnd: "-->",
        stringDelimiters: ["\"", "'"]
    )

    static let xml = LanguageDefinition(
        name: "XML",
        extensions: ["xml", "xsl", "xslt", "xsd", "svg", "plist"],
        keywords: [],
        types: [],
        constants: [],
        lineComment: nil,
        blockCommentStart: "<!--",
        blockCommentEnd: "-->",
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - CSS

    static let css = LanguageDefinition(
        name: "CSS",
        extensions: ["css", "scss", "sass", "less"],
        keywords: [
            "@import", "@media", "@font-face", "@keyframes", "@charset",
            "@supports", "@namespace", "@page", "@property", "!important",
        ],
        types: [],
        constants: [
            "inherit", "initial", "unset", "revert", "none", "auto", "transparent",
            "currentColor", "true", "false",
        ],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - JSON/YAML

    static let json = LanguageDefinition(
        name: "JSON",
        extensions: ["json", "jsonc"],
        keywords: [],
        types: [],
        constants: ["true", "false", "null"],
        lineComment: nil,
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\""]
    )

    static let yaml = LanguageDefinition(
        name: "YAML",
        extensions: ["yaml", "yml"],
        keywords: [],
        types: [],
        constants: ["true", "false", "null", "yes", "no", "on", "off"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - Markdown

    static let markdown = LanguageDefinition(
        name: "Markdown",
        extensions: ["md", "markdown", "mkd"],
        keywords: [],
        types: [],
        constants: [],
        lineComment: nil,
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: []
    )

    // MARK: - SQL

    static let sql = LanguageDefinition(
        name: "SQL",
        extensions: ["sql", "mysql", "pgsql", "sqlite"],
        keywords: [
            "ADD", "ALL", "ALTER", "AND", "AS", "ASC", "BETWEEN", "BY", "CASE",
            "CHECK", "COLUMN", "CONSTRAINT", "CREATE", "DATABASE", "DEFAULT",
            "DELETE", "DESC", "DISTINCT", "DROP", "ELSE", "END", "EXISTS",
            "FOREIGN", "FROM", "FULL", "GROUP", "HAVING", "IF", "IN", "INDEX",
            "INNER", "INSERT", "INTO", "IS", "JOIN", "KEY", "LEFT", "LIKE",
            "LIMIT", "NOT", "NULL", "ON", "OR", "ORDER", "OUTER", "PRIMARY",
            "REFERENCES", "RIGHT", "SELECT", "SET", "TABLE", "THEN", "TOP",
            "TRUNCATE", "UNION", "UNIQUE", "UPDATE", "VALUES", "VIEW", "WHEN",
            "WHERE", "WITH",
        ],
        types: [
            "INT", "INTEGER", "BIGINT", "SMALLINT", "TINYINT", "FLOAT", "DOUBLE",
            "DECIMAL", "NUMERIC", "CHAR", "VARCHAR", "TEXT", "BLOB", "DATE",
            "TIME", "DATETIME", "TIMESTAMP", "BOOLEAN", "BOOL", "SERIAL",
        ],
        constants: ["TRUE", "FALSE", "NULL"],
        lineComment: "--",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - PHP

    static let php = LanguageDefinition(
        name: "PHP",
        extensions: ["php", "php3", "php4", "php5", "phtml"],
        keywords: [
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
        ],
        types: [
            "array", "bool", "boolean", "callable", "double", "float", "int",
            "integer", "iterable", "mixed", "null", "numeric", "object",
            "resource", "string", "void", "never",
        ],
        constants: ["true", "false", "null", "TRUE", "FALSE", "NULL", "__CLASS__", "__DIR__", "__FILE__", "__FUNCTION__", "__LINE__", "__METHOD__", "__NAMESPACE__", "__TRAIT__"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'"],
        preprocessorPrefix: nil
    )

    // MARK: - Kotlin

    static let kotlin = LanguageDefinition(
        name: "Kotlin",
        extensions: ["kt", "kts"],
        keywords: [
            "abstract", "actual", "annotation", "as", "break", "by", "catch",
            "class", "companion", "const", "constructor", "continue", "crossinline",
            "data", "do", "dynamic", "else", "enum", "expect", "external",
            "false", "final", "finally", "for", "fun", "get", "if", "import",
            "in", "infix", "init", "inline", "inner", "interface", "internal",
            "is", "lateinit", "noinline", "null", "object", "open", "operator",
            "out", "override", "package", "private", "protected", "public",
            "reified", "return", "sealed", "set", "super", "suspend", "tailrec",
            "this", "throw", "true", "try", "typealias", "typeof", "val", "var",
            "vararg", "when", "where", "while",
        ],
        types: [
            "Any", "Boolean", "Byte", "Char", "Double", "Float", "Int", "Long",
            "Nothing", "Short", "String", "Unit", "Array", "List", "Map", "Set",
            "MutableList", "MutableMap", "MutableSet", "Sequence", "Pair",
            "Triple",
        ],
        constants: ["true", "false", "null"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/"
    )

    // MARK: - Scala

    static let scala = LanguageDefinition(
        name: "Scala",
        extensions: ["scala", "sc"],
        keywords: [
            "abstract", "case", "catch", "class", "def", "do", "else", "enum",
            "export", "extends", "extension", "false", "final", "finally", "for",
            "forSome", "given", "if", "implicit", "import", "infix", "inline",
            "lazy", "macro", "match", "new", "null", "object", "opaque",
            "open", "override", "package", "private", "protected", "return",
            "sealed", "super", "then", "this", "throw", "trait", "transparent",
            "true", "try", "type", "using", "val", "var", "while", "with",
            "yield",
        ],
        types: [
            "Any", "AnyRef", "AnyVal", "Boolean", "Byte", "Char", "Double",
            "Float", "Int", "Long", "Nothing", "Null", "Short", "String", "Unit",
            "Array", "List", "Map", "Option", "Set", "Seq", "Vector", "Future",
            "Either", "Try",
        ],
        constants: ["true", "false", "null", "Nil", "None"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/"
    )

    // MARK: - Haskell

    static let haskell = LanguageDefinition(
        name: "Haskell",
        extensions: ["hs", "lhs"],
        keywords: [
            "as", "case", "class", "data", "default", "deriving", "do", "else",
            "family", "forall", "foreign", "hiding", "if", "import", "in",
            "infix", "infixl", "infixr", "instance", "let", "mdo", "module",
            "newtype", "of", "proc", "qualified", "rec", "then", "type", "where",
        ],
        types: [
            "Bool", "Char", "Double", "Either", "Float", "Int", "Integer", "IO",
            "Maybe", "Ordering", "String", "Word",
        ],
        constants: ["True", "False", "Nothing", "Just", "Left", "Right", "LT", "GT", "EQ"],
        lineComment: "--",
        blockCommentStart: "{-",
        blockCommentEnd: "-}",
        stringDelimiters: ["\""]
    )

    // MARK: - Perl

    static let perl = LanguageDefinition(
        name: "Perl",
        extensions: ["pl", "pm", "pod", "t"],
        keywords: [
            "and", "cmp", "continue", "do", "else", "elsif", "eq", "for",
            "foreach", "ge", "gt", "if", "last", "le", "lt", "my", "ne", "next",
            "no", "not", "or", "our", "package", "redo", "return", "sub",
            "unless", "until", "use", "while", "xor",
        ],
        types: [],
        constants: ["undef", "__FILE__", "__LINE__", "__PACKAGE__"],
        lineComment: "#",
        blockCommentStart: "=pod",
        blockCommentEnd: "=cut",
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - R

    static let r = LanguageDefinition(
        name: "R",
        extensions: ["r", "R", "rds", "rda"],
        keywords: [
            "break", "else", "for", "function", "if", "in", "next", "repeat",
            "return", "while", "TRUE", "FALSE", "NULL", "NA", "NA_integer_",
            "NA_real_", "NA_complex_", "NA_character_", "Inf", "NaN",
        ],
        types: [],
        constants: ["TRUE", "FALSE", "NULL", "NA", "Inf", "NaN"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - Julia

    static let julia = LanguageDefinition(
        name: "Julia",
        extensions: ["jl"],
        keywords: [
            "abstract", "baremodule", "begin", "break", "catch", "const",
            "continue", "do", "else", "elseif", "end", "export", "finally",
            "for", "function", "global", "if", "import", "in", "let", "local",
            "macro", "module", "mutable", "primitive", "quote", "return",
            "struct", "try", "type", "using", "where", "while",
        ],
        types: [
            "Any", "Array", "Bool", "Char", "Complex", "Dict", "Float16",
            "Float32", "Float64", "Function", "Int", "Int8", "Int16", "Int32",
            "Int64", "Int128", "Integer", "IO", "Matrix", "Nothing", "Number",
            "Rational", "Real", "Set", "String", "Symbol", "Tuple", "Type",
            "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "UInt128", "Vector",
        ],
        constants: ["true", "false", "nothing", "missing", "Inf", "NaN", "pi"],
        lineComment: "#",
        blockCommentStart: "#=",
        blockCommentEnd: "=#",
        stringDelimiters: ["\""]
    )

    // MARK: - Elixir

    static let elixir = LanguageDefinition(
        name: "Elixir",
        extensions: ["ex", "exs"],
        keywords: [
            "after", "alias", "and", "case", "catch", "cond", "def", "defcallback",
            "defdelegate", "defexception", "defguard", "defguardp", "defimpl",
            "defmacro", "defmacrop", "defmodule", "defoverridable", "defp",
            "defprotocol", "defstruct", "do", "else", "end", "fn", "for", "if",
            "import", "in", "not", "or", "quote", "raise", "receive", "require",
            "rescue", "try", "unless", "unquote", "use", "when", "with",
        ],
        types: [],
        constants: ["true", "false", "nil"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - Clojure

    static let clojure = LanguageDefinition(
        name: "Clojure",
        extensions: ["clj", "cljs", "cljc", "edn"],
        keywords: [
            "catch", "def", "defmacro", "defn", "defn-", "do", "finally", "fn",
            "if", "let", "loop", "new", "quote", "recur", "set!", "throw", "try",
            "var", "cond", "case", "when", "when-not", "when-let", "when-first",
            "if-let", "if-not", "if-some", "when-some", "doseq", "dotimes",
            "while", "for", "require", "import", "use", "ns",
        ],
        types: [],
        constants: ["true", "false", "nil"],
        lineComment: ";",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\""]
    )

    // MARK: - Erlang

    static let erlang = LanguageDefinition(
        name: "Erlang",
        extensions: ["erl", "hrl"],
        keywords: [
            "after", "and", "andalso", "band", "begin", "bnot", "bor", "bsl",
            "bsr", "bxor", "case", "catch", "cond", "div", "end", "fun", "if",
            "let", "not", "of", "or", "orelse", "receive", "rem", "try", "when",
            "xor",
        ],
        types: [],
        constants: ["true", "false", "undefined"],
        lineComment: "%",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\""]
    )

    // MARK: - Zig

    static let zig = LanguageDefinition(
        name: "Zig",
        extensions: ["zig"],
        keywords: [
            "addrspace", "align", "allowzero", "and", "anyframe", "anytype",
            "asm", "async", "await", "break", "callconv", "catch", "comptime",
            "const", "continue", "defer", "else", "enum", "errdefer", "error",
            "export", "extern", "fn", "for", "if", "inline", "linksection",
            "noalias", "nosuspend", "opaque", "or", "orelse", "packed", "pub",
            "resume", "return", "struct", "suspend", "switch", "test",
            "threadlocal", "try", "union", "unreachable", "usingnamespace",
            "var", "volatile", "while",
        ],
        types: [
            "bool", "f16", "f32", "f64", "f80", "f128", "c_longdouble",
            "comptime_float", "comptime_int", "isize", "usize", "void", "noreturn",
            "type", "anyerror", "anyopaque",
        ],
        constants: ["true", "false", "null", "undefined"],
        lineComment: "//",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\""]
    )

    // MARK: - Nim

    static let nim = LanguageDefinition(
        name: "Nim",
        extensions: ["nim", "nims"],
        keywords: [
            "addr", "and", "as", "asm", "bind", "block", "break", "case", "cast",
            "concept", "const", "continue", "converter", "defer", "discard",
            "distinct", "div", "do", "elif", "else", "end", "enum", "except",
            "export", "finally", "for", "from", "func", "if", "import", "in",
            "include", "interface", "is", "isnot", "iterator", "let", "macro",
            "method", "mixin", "mod", "nil", "not", "notin", "object", "of",
            "or", "out", "proc", "ptr", "raise", "ref", "return", "shl", "shr",
            "static", "template", "try", "tuple", "type", "using", "var", "when",
            "while", "xor", "yield",
        ],
        types: [
            "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16",
            "uint32", "uint64", "float", "float32", "float64", "bool", "char",
            "string", "cstring", "pointer", "typedesc", "void", "auto", "any",
            "seq", "array", "openArray", "set", "tuple", "object", "ref", "ptr",
        ],
        constants: ["true", "false", "nil"],
        lineComment: "#",
        blockCommentStart: "#[",
        blockCommentEnd: "]#",
        stringDelimiters: ["\""]
    )

    // MARK: - TOML

    static let toml = LanguageDefinition(
        name: "TOML",
        extensions: ["toml"],
        keywords: [],
        types: [],
        constants: ["true", "false"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - Makefile

    static let makefile = LanguageDefinition(
        name: "Makefile",
        extensions: ["mk", "mak"],
        keywords: [
            "define", "endef", "undefine", "ifdef", "ifndef", "ifeq", "ifneq",
            "else", "endif", "include", "sinclude", "override", "export",
            "unexport", "private", "vpath",
        ],
        types: [],
        constants: [],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - Dockerfile

    static let dockerfile = LanguageDefinition(
        name: "Dockerfile",
        extensions: ["dockerfile"],
        keywords: [
            "ADD", "ARG", "CMD", "COPY", "ENTRYPOINT", "ENV", "EXPOSE", "FROM",
            "HEALTHCHECK", "LABEL", "MAINTAINER", "ONBUILD", "RUN", "SHELL",
            "STOPSIGNAL", "USER", "VOLUME", "WORKDIR",
        ],
        types: [],
        constants: [],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - Terraform/HCL

    static let terraform = LanguageDefinition(
        name: "Terraform",
        extensions: ["tf", "tfvars", "hcl"],
        keywords: [
            "data", "locals", "module", "output", "provider", "resource",
            "terraform", "variable", "for_each", "count", "depends_on",
            "lifecycle", "connection", "provisioner",
        ],
        types: ["string", "number", "bool", "list", "map", "set", "object", "tuple", "any"],
        constants: ["true", "false", "null"],
        lineComment: "#",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\""]
    )

    // MARK: - GraphQL

    static let graphql = LanguageDefinition(
        name: "GraphQL",
        extensions: ["graphql", "gql"],
        keywords: [
            "directive", "enum", "extend", "fragment", "implements", "input",
            "interface", "mutation", "on", "query", "scalar", "schema",
            "subscription", "type", "union",
        ],
        types: ["Boolean", "Float", "ID", "Int", "String"],
        constants: ["true", "false", "null"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\""]
    )

    // MARK: - Protobuf

    static let protobuf = LanguageDefinition(
        name: "Protocol Buffers",
        extensions: ["proto"],
        keywords: [
            "enum", "extend", "extensions", "import", "message", "oneof",
            "option", "optional", "package", "public", "repeated", "required",
            "reserved", "returns", "rpc", "service", "syntax", "to", "weak",
        ],
        types: [
            "bool", "bytes", "double", "fixed32", "fixed64", "float", "int32",
            "int64", "sfixed32", "sfixed64", "sint32", "sint64", "string",
            "uint32", "uint64", "map",
        ],
        constants: ["true", "false"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\""]
    )

    // MARK: - Assembly (x86)

    static let assembly = LanguageDefinition(
        name: "Assembly",
        extensions: ["asm", "s", "S"],
        keywords: [
            "section", "segment", "global", "extern", "bits", "use16", "use32",
            "use64", "default", "equ", "times", "db", "dw", "dd", "dq", "dt",
            "resb", "resw", "resd", "resq", "rest", "incbin", "align", "alignb",
            "struc", "endstruc", "istruc", "iend", "at", "macro", "endmacro",
            "%define", "%undef", "%assign", "%macro", "%endmacro", "%if",
            "%elif", "%else", "%endif", "%include",
        ],
        types: [],
        constants: [],
        lineComment: ";",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - HolyC (TempleOS)

    static let holyC = LanguageDefinition(
        name: "HolyC",
        extensions: ["hc", "HC", "holyc"],
        keywords: [
            "asm", "break", "case", "catch", "class", "const", "continue",
            "default", "do", "else", "extern", "false", "for", "goto", "if",
            "import", "in", "interrupt", "lastclass", "lock", "no_warn",
            "noreg", "nowarn", "public", "reg", "return", "sizeof", "static",
            "switch", "true", "try", "union", "while",
        ],
        types: [
            "Bool", "I0", "I8", "I16", "I32", "I64", "U0", "U8", "U16", "U32",
            "U64", "F64", "CDate", "CDateStruct", "CDC", "CDirEntry", "CFifoI64",
            "CFifoU8", "CFile", "CHashExport", "CHashFun", "CHashGeneric",
            "CHashGlblVar", "CHashSrcSym", "CHashTable", "CHeapCtrl", "CJob",
            "CMemBlk", "CTask", "CDoc", "CDocEntry",
        ],
        constants: [
            "TRUE", "FALSE", "NULL", "ON", "OFF", "AUTO", "CH_CTRLA", "CH_CTRLB",
            "CH_CTRLC", "CH_CTRLD", "CH_CTRLE", "CH_CTRLF", "CH_CTRLG", "CH_CTRLH",
            "CH_CTRLI", "CH_CTRLJ", "CH_CTRLK", "CH_CTRLL", "CH_CTRLM", "CH_CTRLN",
            "CH_CTRLO", "CH_CTRLP", "CH_CTRLQ", "CH_CTRLR", "CH_CTRLS", "CH_CTRLT",
            "CH_CTRLU", "CH_CTRLV", "CH_CTRLW", "CH_CTRLX", "CH_CTRLY", "CH_CTRLZ",
            "CH_BACKSPACE", "CH_ESC", "CH_SHIFT_ESC", "CH_SPACE", "CH_SHIFT_SPACE",
        ],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'"],
        preprocessorPrefix: "#",
        specialIdentifiers: ["Print", "Sleep", "GetChar", "PutChar", "StrCpy", "StrCat", "StrLen", "MemCpy", "MemSet", "MAlloc", "Free", "Spawn", "Kill", "Exit"]
    )

    // MARK: - V

    static let vlang = LanguageDefinition(
        name: "V",
        extensions: ["v", "vv"],
        keywords: [
            "as", "asm", "assert", "atomic", "break", "const", "continue",
            "defer", "else", "enum", "false", "fn", "for", "go", "goto", "if",
            "import", "in", "interface", "is", "isreftype", "lock", "match",
            "module", "mut", "none", "or", "pub", "return", "rlock", "select",
            "shared", "sizeof", "spawn", "static", "struct", "true", "type",
            "typeof", "union", "unsafe", "volatile",
        ],
        types: [
            "bool", "byte", "f32", "f64", "i8", "i16", "i32", "i64", "i128",
            "int", "isize", "rune", "string", "u8", "u16", "u32", "u64", "u128",
            "usize", "voidptr", "byteptr", "charptr", "chan", "map", "thread",
        ],
        constants: ["true", "false", "none"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - Odin

    static let odin = LanguageDefinition(
        name: "Odin",
        extensions: ["odin"],
        keywords: [
            "align_of", "auto_cast", "bit_set", "break", "case", "cast",
            "context", "continue", "defer", "distinct", "do", "dynamic",
            "else", "enum", "fallthrough", "false", "for", "foreign", "if",
            "import", "in", "map", "matrix", "nil", "not_in", "offset_of",
            "or_else", "or_return", "package", "proc", "return", "size_of",
            "struct", "switch", "transmute", "true", "type_of", "typeid",
            "union", "using", "when", "where",
        ],
        types: [
            "b8", "b16", "b32", "b64", "bool", "byte", "complex32", "complex64",
            "complex128", "f16", "f32", "f64", "i8", "i16", "i32", "i64", "i128",
            "int", "quaternion64", "quaternion128", "quaternion256", "rawptr",
            "rune", "string", "u8", "u16", "u32", "u64", "u128", "uint", "uintptr",
        ],
        constants: ["true", "false", "nil"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\""]
    )

    // MARK: - Crystal

    static let crystal = LanguageDefinition(
        name: "Crystal",
        extensions: ["cr"],
        keywords: [
            "abstract", "alias", "annotation", "as", "as?", "asm", "begin",
            "break", "case", "class", "def", "do", "else", "elsif", "end",
            "ensure", "enum", "extend", "false", "for", "fun", "if", "in",
            "include", "instance_sizeof", "is_a?", "lib", "macro", "module",
            "next", "nil", "nil?", "of", "offsetof", "out", "pointerof",
            "private", "protected", "require", "rescue", "responds_to?",
            "return", "select", "self", "sizeof", "struct", "super", "then",
            "true", "type", "typeof", "uninitialized", "union", "unless",
            "until", "verbatim", "when", "while", "with", "yield",
        ],
        types: [
            "Bool", "Char", "Float32", "Float64", "Int8", "Int16", "Int32",
            "Int64", "Int128", "Nil", "String", "Symbol", "UInt8", "UInt16",
            "UInt32", "UInt64", "UInt128", "Array", "Hash", "Set", "Tuple",
            "NamedTuple", "Range", "Regex", "Proc", "Pointer", "Slice",
        ],
        constants: ["true", "false", "nil"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - D

    static let dlang = LanguageDefinition(
        name: "D",
        extensions: ["d", "di"],
        keywords: [
            "abstract", "alias", "align", "asm", "assert", "auto", "body",
            "bool", "break", "byte", "case", "cast", "catch", "cdouble",
            "cent", "cfloat", "char", "class", "const", "continue", "creal",
            "dchar", "debug", "default", "delegate", "delete", "deprecated",
            "do", "double", "else", "enum", "export", "extern", "false",
            "final", "finally", "float", "for", "foreach", "foreach_reverse",
            "function", "goto", "idouble", "if", "ifloat", "immutable",
            "import", "in", "inout", "int", "interface", "invariant", "ireal",
            "is", "lazy", "long", "macro", "mixin", "module", "new", "nothrow",
            "null", "out", "override", "package", "pragma", "private",
            "protected", "public", "pure", "real", "ref", "return", "scope",
            "shared", "short", "static", "struct", "super", "switch",
            "synchronized", "template", "this", "throw", "true", "try",
            "typeid", "typeof", "ubyte", "ucent", "uint", "ulong", "union",
            "unittest", "ushort", "version", "void", "wchar", "while", "with",
        ],
        types: [
            "bool", "byte", "ubyte", "short", "ushort", "int", "uint", "long",
            "ulong", "cent", "ucent", "float", "double", "real", "ifloat",
            "idouble", "ireal", "cfloat", "cdouble", "creal", "char", "wchar",
            "dchar", "string", "wstring", "dstring", "size_t", "ptrdiff_t",
        ],
        constants: ["true", "false", "null"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'", "`"]
    )

    // MARK: - OCaml

    static let ocaml = LanguageDefinition(
        name: "OCaml",
        extensions: ["ml", "mli"],
        keywords: [
            "and", "as", "assert", "asr", "begin", "class", "constraint", "do",
            "done", "downto", "else", "end", "exception", "external", "false",
            "for", "fun", "function", "functor", "if", "in", "include",
            "inherit", "initializer", "land", "lazy", "let", "lor", "lsl",
            "lsr", "lxor", "match", "method", "mod", "module", "mutable", "new",
            "nonrec", "object", "of", "open", "or", "private", "rec", "sig",
            "struct", "then", "to", "true", "try", "type", "val", "virtual",
            "when", "while", "with",
        ],
        types: [
            "int", "float", "bool", "char", "string", "bytes", "unit", "list",
            "array", "option", "ref", "exn", "format", "lazy_t",
        ],
        constants: ["true", "false", "None", "Some"],
        lineComment: nil,
        blockCommentStart: "(*",
        blockCommentEnd: "*)",
        stringDelimiters: ["\""]
    )

    // MARK: - F#

    static let fsharp = LanguageDefinition(
        name: "F#",
        extensions: ["fs", "fsi", "fsx", "fsscript"],
        keywords: [
            "abstract", "and", "as", "assert", "base", "begin", "class",
            "default", "delegate", "do", "done", "downcast", "downto", "elif",
            "else", "end", "exception", "extern", "false", "finally", "fixed",
            "for", "fun", "function", "global", "if", "in", "inherit", "inline",
            "interface", "internal", "lazy", "let", "let!", "match", "match!",
            "member", "module", "mutable", "namespace", "new", "not", "null",
            "of", "open", "or", "override", "private", "public", "rec", "return",
            "return!", "select", "static", "struct", "then", "to", "true", "try",
            "type", "upcast", "use", "use!", "val", "void", "when", "while",
            "with", "yield", "yield!",
        ],
        types: [
            "bool", "byte", "sbyte", "int16", "uint16", "int", "uint32", "int64",
            "uint64", "nativeint", "unativeint", "char", "string", "decimal",
            "unit", "float", "float32", "single", "double", "seq", "list",
            "array", "option", "voption", "result", "async", "task",
        ],
        constants: ["true", "false", "null", "None", "Some"],
        lineComment: "//",
        blockCommentStart: "(*",
        blockCommentEnd: "*)",
        stringDelimiters: ["\""]
    )

    // MARK: - Dart

    static let dart = LanguageDefinition(
        name: "Dart",
        extensions: ["dart"],
        keywords: [
            "abstract", "as", "assert", "async", "await", "base", "break",
            "case", "catch", "class", "const", "continue", "covariant",
            "default", "deferred", "do", "dynamic", "else", "enum", "export",
            "extends", "extension", "external", "factory", "false", "final",
            "finally", "for", "Function", "get", "hide", "if", "implements",
            "import", "in", "interface", "is", "late", "library", "mixin",
            "new", "null", "on", "operator", "part", "required", "rethrow",
            "return", "sealed", "set", "show", "static", "super", "switch",
            "sync", "this", "throw", "true", "try", "typedef", "var", "void",
            "when", "while", "with", "yield",
        ],
        types: [
            "bool", "double", "dynamic", "int", "num", "Object", "String",
            "void", "List", "Map", "Set", "Iterable", "Future", "Stream",
            "Function", "Type", "Symbol", "Null", "Never",
        ],
        constants: ["true", "false", "null"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        stringDelimiters: ["\"", "'"]
    )

    // MARK: - All Languages

    static let all: [LanguageDefinition] = [
        c, cpp, objc, swift, javascript, typescript, python, rust, go, java,
        ruby, shell, lua, html, xml, css, json, yaml, markdown, sql, php,
        kotlin, scala, haskell, perl, r, julia, elixir, clojure, erlang, zig,
        nim, toml, makefile, dockerfile, terraform, graphql, protobuf, assembly,
        holyC, vlang, odin, crystal, dlang, ocaml, fsharp, dart,
    ]
}
