# -*- coding: utf-8 -*-

=begin
LETTER = [_a-zA-Z]
DIGIT  = [0-9]
COMMENT              = (--|//).*$
WHITE_SPACE          = [ \t\v\f\r\n]+
SEMICOLON            = ;
LEFT_PARENTHESIS     = (
RIGHT_PARENTHESIS    = )
LEFT_SQUARE_BRACKET  = [
RIGHT_SQUARE_BRACKET = ]
LEFT_CURLY_BRACKET   = {
RIGHT_CURLY_BRACKET  = }
COMMA                = ,
PLUS  = +
MINUS = -
MUL   = *
DIV   = /
MOD   = %
POWER = **
LT    = <
GT    = >
LE    = <=
GE    = >=
EQL   = ==
NEQ    = !=
LOGICAL_AND = &&
LOGICAL_OR  = ||
NUMERIC           = DIGIT+(\.DIGIT*)?
WORD              = LETTER+(LETTER|DIGIT)*
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
			:SEMICOLON,      # ;
			:LEFT_PARENTHESIS,     # (
			:RIGHT_PARENTHESIS,    # )
			:LEFT_SQUARE_BRACKET,  # [
			:RIGHT_SQUARE_BRACKET, # ]
			:LEFT_CURLY_BRACKET,   # {
			:RIGHT_CURLY_BRACKET,  # }
			:COMMA,          # ,
			:PLUS,           # +
			:MINUS,          # -
			:MUL,            # *
			:DIV,            # /
			:MOD,            # %
			:POWER,          # **
			:LT,             # <
			:GT,             # >
			:LE,             # <=
			:GE,             # >=
			:EQL,            # ==
			:NEQ,            # !=
			:LOGICAL_AND,    # &&
			:LOGICAL_OR,     # ||

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
		when '+'
			new_token(:PLUS, get_char)
		when '-'
			char = get_char
			case peek_char
			when '-'
				skip_common
				get_token
			else
				new_token(:MINUS, char)
			end
		when '*'
			char = get_char
			case peek_char
			when '*'
				new_token(:POWER, char << get_char)
			else
				new_token(:MUL, char)
			end
		when '/'
			char = get_char
			case peek_char
			when '/'
				skip_common
				get_token
			else
				new_token(:DIV, char)
			end
		when '<'
			char = get_char
			case peek_char
			when '='
				new_token(:LE, char << get_char)
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
				new_token(:UNKOWN, char)
			end
		when '!'
			char = get_char
			case peek_char
			when '='
				new_token(:NEQ, char << get_char)
			else
				new_token(:UNKOWN, char)
			end
		when '&'
			char = get_char
			case peek_char
			when '&'
				new_token(:LOGICAL_AND, char << get_char)
			else
				new_token(:UNKOWN, char)
			end
		when '|'
			char = get_char
			case peek_char
			when '|'
				new_token(:LOGICAL_OR, char << get_char)
			else
				new_token(:UNKOWN, char)
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