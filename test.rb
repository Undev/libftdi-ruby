require 'rubygems'
require 'bundler/setup'

$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(__FILE__)))

require 'ftdi'

context = Ftdi::Context.open

puts "Context is:"
context.members.each { |k| puts "#{k} = #{context[k]}" }

begin
  context.usb_open(0x0403, 0x6001)
  begin

  ensure
    context.usb_close
  end
rescue Ftdi::Error => e
  $stderr.puts e.to_s
end

context.close

