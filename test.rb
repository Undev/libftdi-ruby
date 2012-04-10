require 'rubygems'
require 'bundler/setup'

$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(__FILE__)))

require 'ftdi'

r = Ftdi.init

r.members.each { |k| puts "#{k} = #{r[k]}" }

Ftdi.deinit(r)

