# -*- coding: utf-8 -*-

=begin
letter = 'a' | 'b' | ... | 'z' | '_' 
digit  = '0' | '1' | ... | '9'
comment              = (--|//).*$
white-space          = [ \t\v\f\r\n]+
comma                = ','
semicolon            = ';'
left_parenthesis     = '('
right_parenthesis    = ')'
left_square_bracket  = '['
right_square_bracket = ']'
left_curly_bracket   = '{'
right_curly_bracket  = '}'
plus      = '+'
minus     = '-'
mul       = '*'
div       = '/'
mod       = '%'
pow       = '**'
cmp       = '<=>'
lt        = '<
gt        = '>'
le        = '<='
ge        = '>='
eql       = '=='
neq       = '!='
LOGIC_NOT = '!'
LOGIC_AND = '&&'
LOGIC_OR  = '||'
BIT_AND   = '&'
BIT_OR    = '|'
BIT_XOR   = '^'
assign    = '='
numeric = digit , { digit } , [ '.' , { digit } ]
word    = letter, { letter } , { letter | digit }
=end

class Lexer
	KEYWORDS = [
		/for/i,
		/from/i,
		/is/i,
		/step/i,
		/to/i,
		/begin/i,
		/end/i,
	]

	class Token
		TYPES = [
			:EOF,            # EOF
			:COMMA,     # ,
			:SEMICOLON, # ;
			:LEFT_PARENTHESIS,     # (
			:RIGHT_PARENTHESIS,    # )
			:LEFT_SQUARE_BRACKET,  # [
			:RIGHT_SQUARE_BRACKET, # ]
			:LEFT_CURLY_BRACKET,   # {
			:RIGHT_CURLY_BRACKET,  # }
			:PLUS,         # +
			:MINUS,        # -
			:MUL,          # *
			:DIV,          # /
			:MOD,          # %
			:POW,          # **
			:CMP,          # <=>
			:LT,           # <
			:GT,           # >
			:LE,           # <=
			:GE,           # >=
			:EQL,          # ==
			:NEQ,          # !=
			:LOGIC_NOT,    # !
			:LOGIC_AND,    # &&
			:LOGIC_OR,     # ||
			:BIT_AND,      # &
			:BIT_OR,       # |
			:BIT_XOR,      # ^
			:ASSIGN,       # =

			:NUMERIC,        # 数字字面量
			:IDENTIFIER,     # 标识符

			# 关键字
			:FOR,
			:FROM,
			:IS,
			:STEP,
			:TO,
			:BEGIN,
			:END,

			:UNKOWN,         # 异常字符
		]

		attr_reader :type, :value

		def initialize(type, value, line, colume)
			raise unless TYPES.include?(type)
			@type, @value = type, value
			@line, @colume = line, colume
		end

		def to_s
			"<%<line>3d %<colume>3d %<type>s %<value>s >" % { type: @type, value: @value.inspect, line: @line, colume: @colume }
		end
	end

	def initialize(io)
		@io = io
		@char_buffer = []
		@line = 1
		@colume, @last_colume = 1, 1
	end

	def get_char
		char = @char_buffer.empty? ? @io.getc : @char_buffer.pop
		if char == "\n"
			@line += 1
			@colume, @last_colume = 1, @colume
		else
			@colume += 1
		end
		char
	end

	def peek_char
		unget_char(get_char) if @char_buffer.empty?
		@char_buffer.last
	end

	def unget_char(char)
		if @colume > 1
			@colume -= 1
		else
			@line -= 1
			@colume, @last_colume = @last_colume, 1
		end
		@char_buffer.push(char)
	end

	def new_token(type, value, line = @line, colume = @colume)
		Token.new(type, value, line, colume)
	end

	# 略过空白符
	def skip_whitespace
		get_char while peek_char =~ /[ \t\v\f\r\n]|[\000\004\032]/
	end

	# 略过注释符
	def skip_common
		get_char until peek_char =~ /[\r\n]|[\000\004\032]/
	end

	def get_word
		word = get_char
		word << get_char while peek_char =~ /[_0-9a-zA-Z]/
		word
	end

	def get_numeric
		numeric = get_char
		numeric << get_char while peek_char =~ /[0-9]/
		if peek_char == '.'
			numeric << get_char
			numeric << get_char while peek_char =~ /[0-9]/
			numeric << '0'
			Float(numeric)
		else
			Integer(numeric)
		end
	end

	def get_token
		return new_token(:EOF, '\000') if @io.eof?
		case peek_char
		when /[\000\004\032]/ # NUL, ^D, ^Z
			return new_token(:EOF, '\000')
		when /[ \t\f\r\n\v]/ # white spaces
			skip_whitespace
			get_token
		when '#'
			get_char
			skip_common
			get_token
		when '+'
			new_token(:PLUS, get_char)
		when '-'
			char = get_char
			case peek_char
			when '-'
				get_char
				skip_common
				get_token
			else
				new_token(:MINUS, char)
			end
		when '*'
			char = get_char
			case peek_char
			when '*'
				new_token(:POW, char << get_char)
			else
				new_token(:MUL, char)
			end
		when '/'
			char = get_char
			case peek_char
			when '/'
				get_char
				skip_common
				get_token
			else
				new_token(:DIV, char)
			end
		when '<'
			char = get_char
			case peek_char
			when '='
				char << get_char
				case peek_char
				when '>'
					new_token(:CMP, char << get_char)
				else
					new_token(:LE, char)
				end
			else
				new_token(:LT, char)
			end
		when '>'
			char = get_char
			case peek_char
			when '='
				new_token(:GE, char << get_char)
			else
				new_token(:GT, char)
			end
		when '='
			char = get_char
			case peek_char
			when '='
				new_token(:EQL, char << get_char)
			else
				new_token(:ASSIGN, char)
			end
		when '!'
			char = get_char
			case peek_char
			when '='
				new_token(:NEQ, char << get_char)
			else
				new_token(:LOGIC_NOT, char)
			end
		when '&'
			char = get_char
			case peek_char
			when '&'
				new_token(:LOGIC_AND, char << get_char)
			else
				new_token(:BIT_AND, char)
			end
		when '|'
			char = get_char
			case peek_char
			when '|'
				new_token(:LOGIC_OR, char << get_char)
			else
				new_token(:BIT_OR, char)
			end
		when '%'
			new_token(:MOD, get_char)
		when '('
			new_token(:LEFT_PARENTHESIS, get_char)
		when ')'
			new_token(:RIGHT_PARENTHESIS, get_char)
		when '['
			new_token(:LEFT_SQUARE_BRACKET, get_char)
		when ']'
			new_token(:RIGHT_SQUARE_BRACKET, get_char)
		when '{'
			new_token(:LEFT_CURLY_BRACKET, get_char)
		when '}'
			new_token(:RIGHT_CURLY_BRACKET, get_char)
		when ','
			new_token(:COMMA, get_char)
		when ';'
			new_token(:SEMICOLON, get_char)
		when /[_a-zA-Z]/
			word = get_word
			if KEYWORDS.one? {|keyword| word =~ keyword}
				word = word.upcase.to_sym
				new_token(word, word)
			else
				new_token(:IDENTIFIER, word.downcase.to_sym)
			end
		when /[0-9]/
			new_token(:NUMERIC, get_numeric)
		else
			new_token(:UNKOWN, get_char)
		end
	end
end