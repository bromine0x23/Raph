#! ruby
# -*- coding: utf-8 -*-

require_relative 'lexer'
require_relative 'syntax'

lexer = Lexer.new(File.open('test.raph'))

#=begin
begin
	token = lexer.get_token
	puts token
end until not token or token.type == :EOF
#=end

syntax = Syntax.new(File.open('test.raph'))

result = syntax.analysis

p result

result.call