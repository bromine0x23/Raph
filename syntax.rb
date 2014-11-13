# -*- coding: utf-8 -*-

require 'chunky_png'
require_relative 'lexer'

=begin

letter = '_' | 'a' | 'b' | ... | 'z'

digit = '0' | '1' | ... | '9'

id = letter , { letter | digit }

numeric = digit , [ '.' , { digit } ]

program = stmts

stmts = { stmt }

stmt = block | for-stmt | call-or-assgin

block = 'begin' , stmts , 'end'

for-stmt = 'for' , id , 'from' , expr , 'to' , expr , 'step' , expr , stmt

call-or-assgin = id , ( call-r | assign-r ) , ';'

call-r = '(' , [ args ] , ')'

args = expr , { ',' , expr }

assign-r = 'is' , expr

expr = logical-or-expr

logical-or-expr = logical-and-expr , { '||' , logical-and-expr }

logical-and-expr = eql-neq-expr , { '&&' , eql-neq-expr }

eql-neq-expr = relation-expr , { ( '==' | '!=' ) , relation-expr }

relation-expr = add-sub-expr , { ( '<' | '>' | '<=' | '>=' ) , add-sub-expr }

add-sub-expr = mul-div-mod-expr , { ( '+' | '-' ) , mul-div-mod-expr }

mul-div-mod-expr = power-expr , { ( '*' | '/' | '%' ) , power-expr }

power-expr = unary-expr , { '**' , unary-expr }

unary-expr = [ '+' | '-' ] , postfix_expr

postfix_expr = primary-expr , [ '(' , [ args ] , ')' | '[' , [ args ] , ']' ]

primary-expr  = numeric | id | '(' expr , [ ',' , expr ] ')'

=end


class Vector2D
	include Comparable
	attr_reader :x, :y
	def initialize(x, y)
		@x, @y = x, y
	end
	def +@
		Vector2D.new(+@x, +@y)
	end
	def -@
		Vector2D.new(-@x, -@y)
	end
	def +(rhs)
		rhs.is_a?(Vector2D) ? Vector2D.new(@x + rhs.x, @y + rhs.y) : Vector2D.new(@x + rhs, @y + rhs)
	end
	def -(rhs)
		rhs.is_a?(Vector2D) ? Vector2D.new(@x - rhs.x, @y - rhs.y) : Vector2D.new(@x - rhs, @y - rhs)
	end
	def *(rhs)
		rhs.is_a?(Vector2D) ? Vector2D.new(@x * rhs.x, @y * rhs.y) : Vector2D.new(@x * rhs, @y * rhs)
	end
	def /(rhs)
		rhs.is_a?(Vector2D) ? Vector2D.new(@x / rhs.x, @y / rhs.y) : Vector2D.new(@x / rhs, @y / rhs)
	end
	def <=>(rhs)
		if @x < rhs.x || (@x == rhs.x && @y < rhs.y)
			-1
		elsif rhs.x < @x || (rhs.x == @x && rhs.y < @y)
			1
		else
			0
		end
	end
	def [](idx)
		idx = Integer(idx)
		case idx
		when 0, -2
			@x
		when 1, -1
			@y
		else
			raise "Out of range #{idx}"
		end
	end
	def rotate(angle)
		sin, cos = Math.sin(angle), Math.cos(angle)
		Vector2D.new(@x * cos + @y * sin, @y * cos - @x * sin)
	end
end

class AmbiguityExeption < ::Exception
end

class UnexpectedToken < ::Exception
	attr_reader :token
	def initialize(token)
		@token = token
		super("Unexpected token #{@token}.")
	end
end

class InvalidVaribale < ::Exception
	def initialize(identifier)
		@identifier = identifier
		super("Invalid Varibale #{@identifier}")
	end
end

module AST
	class Node
		def initialize(*_)
		end

		def call
		end
	end

	class Numeric < Node
		def initialize(numeric)
			super
			@numeric = numeric
		end

		def call
			@numeric
		end
	end

	class ID < Node
		def initialize(id)
			super
			@id = id
		end

		def call
			raise InvalidVaribale.new(@id) unless $raph_space.has_key?(@id)
			$raph_space[@id]
		end
	end

	class Vector < Node
		def initialize(x, y)
			super
			@x, @y = x, y
		end

		def call
			Vector2D.new(@x.call, @y.call)
		end
	end

	class Operator < Node
		def initialize(op)
			super
			@op = op
		end

		def call
			@op
		end
	end

	class Call < Node
		def initialize(id, args)
			super
			@id, @args = id, args
		end

		def call
			(@id.call).call(*@args.map{ |arg| arg.call })
		end
	end

	class UnaryOperate < Node
		def initialize(op, rhs)
			super
			@op, @rhs = op, rhs
		end

		def call
			@rhs.call.send(@op.call)
		end
	end

	class BinaryOperate < Node
		def initialize(lhs, op, rhs)
			super
			@lhs, @op, @rhs = lhs, op, rhs
		end

		def call
			(@lhs.call).send(@op.call, @rhs.call)
		end
	end

	class ArrayAcess < Node
		def initialize(value, args)
			super
			@value, @args = value, args
		end

		def call
			result = (@value.call)[*@args.map{ |arg| arg.call }]
			puts result.inspect
			result
		end
	end

	class Stmts < Node
		def initialize(stmts)
			super
			@stmts = stmts
		end

		def call
			@stmts.each do |stmt|
				stmt.call
			end
		end
	end

	class Block < Stmts
	end

	class ForStmts < Node
		def initialize(id, from, to, step, stmt)
			super
			@id, @from, @to, @step, @stmt = id, from, to, step, stmt
		end

		def call
			throw AmbiguityExeption if $raph_space.has_key?(@id)
			from = @from.call
			to = @to.call
			current = from
			while current <= to
				$raph_space[@id] = current
				@stmt.call
				current += @step.call
			end
			$raph_space.delete(@id)
			current
		end
	end

	class CallStmts < Call
	end

	class AssignStmts < Node
		def initialize(id, expr)
			super
			@id, @expr = id, expr
		end

		def call
			$raph_space[@id] = @expr.call
		end
	end
end

class Syntax
	def initialize(io)
		@lexer = Lexer.new(io)
		@token_buffer = []
	end

	def analysis
		analysis_program
	end

private
	def get_token
		token = @token_buffer.empty? ? @lexer.get_token : @token_buffer.pop
		# puts caller(0, 5)
		# puts "get token #{token}"
		token
	end

	def unget_token(token)
		# puts caller(0, 5)
		# puts "unget token #{token}"
		@token_buffer.push(token)
	end

	def peek_token
		unget_token(get_token) if @token_buffer.empty?
		@token_buffer.last
	end

	def next_token_is?(type)
		peek_token.type == type
	end

	def need_token(type, value = nil, &proc)
		token = get_token
		if token.type == type && (value == nil || token.value == value)
			proc ? proc.call(token) : token
		else
			raise UnexpectedToken.new(token)
		end
	end

	def need_pair(left_type, right_type)
		need_token(left_type) do |token|
			result = yield token unless peek_token.type == right_type
			need_token(right_type)
			result
		end
	end

	def need_one_of(*types)
		token = get_token
		if types.include?(token.type)
			proc ? proc.call(token) : token
		else
			raise UnexpectToken.new(token)
		end
	end

	def analysis_program
		analysis_stmts
	end

	def analysis_stmts
		stmts = []
		while peek_token.type != :EOF
			stmt = analysis_stmt
			stmts << stmt
		end
		AST::Stmts.new(stmts)
	end

	def analysis_stmt
		case peek_token.type
		when :BEGIN
			analysis_block
		when :FOR
			analysis_for_stmt
		when :IDENTIFIER
			analysis_call_or_assign_stmt
		else
			raise UnexpectToken.new(peek_token)
		end
	end

	def analysis_block
		need_token(:BEGIN) do
			stmts = []
			while peek_token.type != :END
				stmt = analysis_stmt
				stmts << stmt
			end
			need_token(:END)
			AST::Block.new(stmts)
		end
	end

	def analysis_for_stmt
		need_token(:FOR) do
			need_token(:IDENTIFIER) do |identifier|
				need_token(:FROM) do
					from = analysis_expr
					need_token(:TO) do
						to = analysis_expr
						need_token(:STEP) do
							step = analysis_expr
							AST::ForStmts.new(
								identifier.value,
								from,
								to,
								step,
								analysis_stmt
							)
						end
					end
				end
			end
		end
	end

	def analysis_args
		args = [ analysis_expr ]
		while peek_token.type == :COMMA
			need_token(:COMMA) do
				expr = analysis_expr
				args << expr
			end
		end
		args
	end

	def analysis_call_or_assign_stmt
		need_token(:IDENTIFIER) do |identifier|
			case peek_token.type
			when :LEFT_PARENTHESIS
				arguments = []
				need_pair(:LEFT_PARENTHESIS, :RIGHT_PARENTHESIS) do
					arguments = analysis_args
				end
				need_token(:SEMICOLON)
				AST::CallStmts.new(
					AST::ID.new(identifier.value),
					arguments
				)
			when :IS
				need_token(:IS) do
					expr = analysis_expr
					need_token(:SEMICOLON)
					AST::AssignStmts.new(
						identifier.value,
						expr
					)
				end
			else
				raise UnexpectedToken.new(peek_token)
			end
		end
	end

	def analysis_expr
		analysis_logical_or_expr
	end

	def analysis_logical_or_expr
		expr = analysis_eql_neq_expr
		loop do
			case peek_token.type
			when :LOGICAL_OR
				need_token(:LOGICAL_OR) do |operator|
					expr = AST::BinaryOperate.new(
						expr,
						AST::Operator.new(operator.value),
						analysis_eql_neq_expr
					)
				end
			else
				break;
			end
		end
		expr
	end

	def analysis_logical_and_expr
		expr = analysis_eql_neq_expr
		loop do
			case peek_token.type
			when :LOGICAL_AND
				need_token(:LOGICAL_AND) do |operator|
					expr = AST::BinaryOperate.new(
						expr,
						AST::Operator.new(operator.value),
						analysis_eql_neq_expr
					)
				end
			else
				break;
			end
		end
		expr
	end

	def analysis_eql_neq_expr
		expr = analysis_relation_expr
		loop do
			case peek_token.type
			when :EQL, :NEQ
				need_one_of(:EQL, :NEQ) do |operator|
					expr = AST::BinaryOperate.new(
						expr,
						AST::Operator.new(operator.value),
						analysis_relation_expr
					)
				end
			else
				break;
			end
		end
		expr
	end

	def analysis_relation_expr
		expr = analysis_add_sub_expr
		loop do
			case peek_token.type
			when :LT, :GT, :LE, :GE
				need_one_of(:LT, :GT, :LE, :GE) do |operator|
					expr = AST::BinaryOperate.new(
						expr,
						AST::Operator.new(operator.value),
						analysis_relation_expr
					)
				end
			else
				break;
			end
		end
		expr
	end

	def analysis_add_sub_expr
		expr = analysis_mul_div_expr
		loop do
			case peek_token.type
			when :PLUS, :MINUS
				need_one_of(:PLUS, :MINUS) do |operator|
					expr = AST::BinaryOperate.new(
						expr,
						AST::Operator.new(operator.value),
						analysis_relation_expr
					)
				end
			else
				break;
			end
		end
		expr
	end

	def analysis_mul_div_expr
		expr = analysis_power_expr
		loop do
			case peek_token.type
			when :MUL, :DIV
				need_one_of(:MUL, :DIV, :MOD) do |operator|
					expr = AST::BinaryOperate.new(
						expr,
						AST::Operator.new(operator.value),
						analysis_relation_expr
					)
				end
			else
				break;
			end
		end
		expr
	end

	def analysis_power_expr
		expr = analysis_unary_expr
		loop do
			case peek_token.type
			when :POWER
				need_token(:POWER) do |operator|
					expr = AST::BinaryOperate.new(
						expr,
						AST::Operator.new(operator.value),
						analysis_relation_expr
					)
				end
			else
				break;
			end
		end
		expr
	end

	def analysis_unary_expr
		case peek_token.type
		when :PLUS, :MINUS
			need_one_of(:PLUS, :MINUS) do |operator|
					AST::UnaryOperate.new(
					AST::Operator.new(:"#{operator.value}@"),
					analysis_postfix_expr
				)
			end
		else
			analysis_postfix_expr
		end
	end

	def analysis_postfix_expr
		expr = analysis_primary_expr
		case peek_token.type
		when :LEFT_PARENTHESIS
			arguments = []
			need_pair(:LEFT_PARENTHESIS, :RIGHT_PARENTHESIS) do
				arguments = analysis_args
			end
			AST::Call.new(
				expr,
				arguments
			)
		when :LEFT_SQUARE_BRACKET
			arguments = []
			need_pair(:LEFT_SQUARE_BRACKET, :RIGHT_SQUARE_BRACKET) do
				arguments = analysis_args
			end
			AST::ArrayAcess.new(
				expr,
				arguments
			)
		else
			expr
		end
	end

	def analysis_primary_expr
		case peek_token.type
		when :NUMERIC
			AST::Numeric.new(get_token.value)
		when :IDENTIFIER
			need_token(:IDENTIFIER) do |identifier|
				AST::ID.new(identifier.value)
			end
		when :LEFT_PARENTHESIS
			need_pair(:LEFT_PARENTHESIS, :RIGHT_PARENTHESIS) do
				expr = analysis_expr
				case peek_token.type
				when :RIGHT_PARENTHESIS
					expr
				when :COMMA
					need_token(:COMMA)
					AST::Vector.new(expr, analysis_expr)
				else
					raise UnexpectedToken.new(peek_token)
				end
			end
		else
			raise UnexpectedToken.new(peek_token)
		end
	end
end

module VM
	extend Math

	def self.init
		$raph_space = {}
		init_global
		init_constant
		set_math_function
		set_graphical_function
	end

	def self.init_global
		$raph_space[:origin] = Vector2D.new(0.0, 0.0)
		$raph_space[:rot] = 0.0
		$raph_space[:scale] = Vector2D.new(1.0, 1.0)
	end

	def self.init_constant
		$raph_space[:pi] = Math::PI
		$raph_space[:e] = Math::E
	end

	def self.set_math_function
		$raph_space[:sin] = -> (x){ sin(x) }
		$raph_space[:cos] = -> (x){ cos(x) }
		$raph_space[:tan] = -> (x){ tan(x) }
		$raph_space[:sinh] = -> (x){ sinh(x) }
		$raph_space[:cosh] = -> (x){ cosh(x) }
		$raph_space[:tanh] = -> (x){ tanh(x) }
		$raph_space[:asin] = -> (x){ asin(x) }
		$raph_space[:acos] = -> (x){ acos(x) }
		$raph_space[:atan] = -> (x){ atan(x) }
		$raph_space[:asinh] = -> (x){ asinh(x) }
		$raph_space[:acosh] = -> (x){ acosh(x) }
		$raph_space[:atanh] = -> (x){ atanh(x) }
		$raph_space[:exp] = -> (x){ exp(x) }
		$raph_space[:ln] = -> (x){ log(x) }
		$raph_space[:log2] = -> (x){ log2(x) }
		$raph_space[:log10] = -> (x){ log10(x) }
		$raph_space[:sqrt] = -> (x){ sqrt(x) }
		$raph_space[:cbrt] = -> (x){ cbrt(x) }
		$raph_space[:rand] = -> { rand() }
		$raph_space[:abs] = -> (x) { x.abs }
		$raph_space[:min] = -> (lhs, rhs){ lhs < rhs ? lhs : rhs }
		$raph_space[:max] = -> (lhs, rhs){ lhs < rhs ? rhs : lhs }
		$raph_space[:ceil] = -> (x){ x.ceil }
		$raph_space[:floor] = -> (x){ x.floor }
		$raph_space[:truncate] = -> (x){ x.truncate }
		$raph_space[:round] = -> (x, n){ x.round(n) }
	end

	def self.set_graphical_function
		@png = ChunkyPNG::Canvas.new(640, 480, ChunkyPNG::Color::TRANSPARENT)
		@color = ChunkyPNG::Color::BLACK
		@radius = 1
		$raph_space[:clear] = -> (width, height){ @png = ChunkyPNG::Canvas.new(Integer(width), Integer(height), ChunkyPNG::Color::TRANSPARENT) }
		$raph_space[:draw] = -> (x, y){
			v = coordinate_transform(x, y)
			if @radius == 1
				@png[Integer(v.x), Integer(v.y)] = @color
			else
				@png.circle(Integer(v.x), Integer(v.y), @radius, @color, @color)
			end
			# puts v.inspect
		}
		$raph_space[:save] = -> { @png.save('raph.png') }
		$raph_space[:set_color] = ->(r, g, b) { @color = ChunkyPNG::Color.rgb(Integer(r), Integer(g), Integer(b)) }
		$raph_space[:set_radius] = ->(radius) { @radius = radius.to_i }
	end

	def self.coordinate_transform(x, y)
		(Vector2D.new(x, y) * $raph_space[:scale]).rotate($raph_space[:rot]) + $raph_space[:origin]
	end

	init
end