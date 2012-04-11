require 'rubygems'
require 'bundler/setup'

$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(__FILE__)))

require 'ftdi'

BAUD_RATE = 250000

ctx = Ftdi::Context.new

begin
  ctx.usb_open(0x0403, 0x6001)
  begin
    ctx.baudrate = BAUD_RATE

    puts "Context is:"
    ctx.members.each { |k| puts "#{k} = #{ctx[k]}" }

  ensure
    ctx.usb_close
  end
rescue Ftdi::Error => e
  $stderr.puts e.to_s
end

ctx.dispose

