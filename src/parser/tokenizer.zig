const std = @import("std");

const source = @import("source.zig");
const Span = source.Span;

pub const Token = struct {
    tag: Tag,
    span: Span,

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "type", .keyword_type },
        .{ "var", .keyword_var },
        .{ "const", .keyword_const },
        .{ "module", .keyword_module },
        .{ "import", .keyword_import },
        .{ "func", .keyword_func },
        .{ "return", .keyword_return },
        .{ "true", .keyword_true },
        .{ "false", .keyword_false },
    });

    pub fn getKeyword(bytes: []const u8) ?Tag {
        return keywords.get(bytes);
    }
    pub const Tag = enum {
        invalid,
        eof,
        keyword_var,
        keyword_const,
        keyword_import,
        keyword_module,
        keyword_type,
        keyword_func,
        keyword_return,
        keyword_true,
        keyword_false,
        built_in,
        uint8,
        uint16,
        uint32,
        uint64,
        uint,
        int8,
        int16,
        int32,
        int64,
        int,
        char,
        float32,
        float64,
        float,
        boolean,
        equal,
        plus,
        minus,
        asterisk,
        percent,
        pipe,
        amperstand,
        bang,
        colon,
        semicolon,
        l_paren,
        r_paren,
        l_brace,
        r_brace,
        l_bracket,
        r_bracket,
        l_angle,
        r_angle,
        at_sign,
        identifier,
        int_literal,
        float_literal,
        multi_line_string_literal,
        string_literal,
        char_literal,
        hex_literal,
        number_literal,
        binary_literal,
        equal_equal,
        plus_equal,
        minus_equal,
        asterisk_equal,
        slash_equal,
        slash_slash,
        amperstand_equal,
        amperstand_amperstand,
        pipe_equal,
        pipe_pipe,
        bang_equal,
        l_angle_equal,
        l_angle_l_angle,
        l_angle_l_angle_equal,
        r_angle_equal,
        r_angle_r_angle,
        r_angle_r_angle_equal,
        dot,
        dot_dot,
        dot_dot_equal,
        comma,
        underscore,
        backslash,
        carat,
        carat_equal,

        pub fn lexeme(self: Tag) ?[]const u8 {
            return switch (self) {
                .invalid,
                .eof,
                .identifier,
                .int_literal,
                .float_literal,
                .multi_line_string_literal,
                .string_literal,
                .char_literal,
                => null,
                .keyword_var => "var",
                .keyword_const => "const",
                .keyword_import => "import",
                .keyword_module => "module",
                .keyword_type => "type",
                .keyword_func => "func",
                .keyword_return => "return",
                .uint8 => "u8",
                .uint16 => "u16",
                .uint32 => "u32",
                .uint64 => "u64",
                .uint => "uint",
                .int8 => "i8",
                .int16 => "i16",
                .int32 => "i32",
                .int64 => "i64",
                .int => "int",
                .char => "char",
                .float32 => "f32",
                .float64 => "f64",
                .float => "float",
                .boolean => "bool",
                .equal => "=",
                .plus => "+",
                .minus => "-",
                .asterisk => "*",
                .percent => "%",
                .pipe => "|",
                .amperstand => "&",
                .bang => "!",
                .colon => ":",
                .semicolon => ";",
                .l_paren => "(",
                .r_paren => ")",
                .l_brace => "{",
                .r_brace => "}",
                .l_bracket => "[",
                .r_bracket => "]",
                .l_angle => "<",
                .r_angle => ">",
                .at_sign => "@",
                .equal_equal => "==",
                .plus_equal => "+=",
                .minus_equal => "-=",
                .asterisk_equal => "*=",
                .slash_equal => "/=",
                .slash_slash => "//",
                .amperstand_equal => "&=",
                .amperstand_amperstand => "&&",
                .pipe_equal => "|=",
                .pipe_pipe => "||",
                .bang_equal => "!=",
                .l_angle_equal => "<=",
                .l_angle_l_angle => "<<",
                .l_angle_l_angle_equal => "<<=",
                .r_angle_equal => "=>",
                .r_angle_r_angle => ">>",
                .r_angle_r_angle_equal => ">>=",
                .dot => ".",
                .dot_dot => "..",
                .dot_dot_equal => "..=",
                .comma => ",",
                .backslash => "\\",
                .underscore => "_",
                .carat => "^",
                .carat_equal => "^=",
            };
        }
        pub fn symbol(tag: Tag) []const u8 {
            return tag.lexeme() orelse switch (tag) {
                .invalid => "invalid Token",
                .eof => "end of file",
                .identifier => "an identifier",
                .int_literal => "an int literal",
                .float_literal => "a float literal",
                .multi_line_string_literal => "a multi line string literal",
                .string_literal => "a string literal",
                .char_literal => "a char literal",
                else => unreachable,
            };
        }
    };
};
pub const Tokenizer = struct {
    buffer: [:0]const u8,
    index: u32,

    pub fn dump(self: *Tokenizer, token: *const Token) void {
        std.debug.print("{s}\"{s}\"\n", .{
            @tagName(token.tag),
            self.buffer[token.span.lo..token.span.hi],
        });
    }

    pub fn init(buffer: [:0]const u8) Tokenizer {
        return .{
            .buffer = buffer,
            .index = if (std.mem.startsWith(u8, buffer, "\xEF\xBB\xBF")) 3 else 0,
        };
    }

    const State = enum {
        start,
        invalid,
        expect_newline,
        string_literal,
        identifier,
        saw_at_sign,
        builtin,
        equal,
        bang,
        pipe,
        l_angle,
        l_angle_l_angle,
        r_angle,
        r_angle_r_angle,
        slash,
        backslash,
        carat,
        plus,
        minus,
        asterisk,
        amperstand,
        dot,
        dot_dot,
        number_literal,
        char_literal,
        char_literal_backslash,
        int,
        float,
    };

    pub fn next(self: *Tokenizer) Token {
        var result: Token = .{
            .tag = undefined,
            .span = .{
                .start = self.index,
                .end = undefined,
            },
        };

        state: switch (State.start) {
            .start => switch (self.buffer[self.index]) {
                0 => {
                    if (self.index == self.buffer.len) {
                        return .{
                            .tag = .eof,
                            .span = .{
                                .start = self.index,
                                .end = self.index,
                            },
                        };
                    }
                },
                ' ', '\n', '\t', '\r' => {
                    self.index += 1;
                    result.span.start = self.index;
                    continue :state .start;
                },
                '"' => {
                    result.tag = .string_literal;
                    continue :state .string_literal;
                },
                '\'' => {
                    result.tag = .char_literal;
                    continue :state .char_literal;
                },

                'a'...'z', 'A'...'Z', '_' => {
                    result.tag = .identifier;
                    continue :state .identifier;
                },
                '@' => continue :state .saw_at_sign,
                '&' => continue :state .amperstand,
                '=' => continue :state .equal,
                '!' => continue :state .pipe,
                '<' => continue :state .l_angle,
                '>' => continue :state .r_angle,
                '!' => continue :state .bang,
                '^' => continue :state .carat,
                '\\' => continue :state .backslash,
                '+' => continue :state .plus,
                '-' => continue :state .minus,
                '.' => continue :state .dot,
                ';' => {
                    result.tag = .semicolon;
                    self.index += 1;
                },
                ',' => {
                    result.tag = .comma;
                    self.index += 1;
                },
                ':' => {
                    result.tag = .colon;
                    self.index += 1;
                },
                '(' => {
                    result.tag = .l_paren;
                    self.index += 1;
                },
                ')' => {
                    result.tag = .r_paren;
                    self.index += 1;
                },
                '{' => {
                    result.tag = .l_brace;
                    self.index += 1;
                },
                '}' => {
                    result.tag = .r_paren;
                    self.index += 1;
                },
                '[' => {
                    result.tag = .l_bracket;
                    self.index += 1;
                },
                ']' => {
                    result.tag = .l_bracket;
                    self.index += 1;
                },
                '0'...'9' => {
                    result.tag = .number_literal;
                    self.index += 1;
                    continue :state .int;
                },
                else => continue :state .invalid,
            },
            .expect_newline => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => {
                        if (self.index == self.buffer.len) {
                            result.tag = .invalid;
                        } else {
                            continue :state .invalid;
                        }
                    },
                    '\n' => {
                        self.index += 1;
                        result.span.start = self.index;
                        continue :state .start;
                    },
                    else => continue :state .invalid,
                }
            },

            .invalid => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0 => if (self.index == self.buffer.len) {
                        result.tag = .invalid;
                    } else {
                        continue :state .invalid;
                    },
                    '\n' => result.tag = .invalid,
                    else => continue :state .invalid,
                }
            },
            .saw_at_sign => {
                self.index += 1;
                switch (self.buffer[self.index]) {
                    0, '\n' => result.tag = .invalid,
                    'a'...'z', 'A'...'Z', '_' => {
                        result.tag = .built_in;
                    },
                    else => continue :state .invalid,
                }
            },
        }
    }
};
