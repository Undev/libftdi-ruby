require 'rubygems'
require 'bundler/setup'

$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(__FILE__)))

require 'ftdi'

DMX_BREAK = 110. / 1000   # Break 88 uS or more
DMX_MAB   = 160. / 1000   # Mark After Break 8 uS or more
BAUD_RATE = 250000

ctx = Ftdi::Context.new

def dmx_break(ctx)
  ctx.set_line_property2(:bits_8, :stop_bit_2, :none, :break_on)
  sleep DMX_BREAK
  ctx.set_line_property2(:bits_8, :stop_bit_2, :none, :break_off)
  sleep DMX_MAB
end

def dmx_write(ctx, bytes)
  dmx_break(ctx)
  ctx.write_data(bytes)
end

begin
  ctx.usb_open(0x0403, 0x6001)
  begin
    puts ctx.interface
    ctx.baudrate = BAUD_RATE
    ctx.set_line_property(:bits_8, :stop_bit_2, :none)
    ctx.flowctrl = Ftdi::SIO_DISABLE_FLOW_CTRL

    arr = Array.new(513) { |i| i.zero? ? 0 : 1 }
    dmx_write(ctx, arr)

    sleep 1

    arr = [ 0 ] * 513
    dmx_write(ctx, arr)

    puts "Context is:"
    ctx.members.each { |k| puts "#{k} = #{ctx[k]}" }

  ensure
    ctx.usb_close
  end
rescue Ftdi::Error => e
  $stderr.puts e.to_s
end

ctx.dispose

