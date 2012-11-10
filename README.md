## Description

Ruby bindings for [libftdi](http://www.intra2net.com/en/developer/libftdi/index.php) - an open source library to talk to [FTDI](http://www.ftdichip.com/) chips.

## Prerequisites

You must install `libftdi` itself in addition to this gem.

## Synopsys

```ruby
require 'rubygems'
require 'ftdi'

ctx = Ftdi::Context.new

begin
  ctx.usb_open(0x0403, 0x6001)
  begin
    ctx.baudrate = 250000
    ctx.set_line_property(:bits_8, :stop_bit_2, :none)
    ctx.flowctrl = Ftdi::SIO_DISABLE_FLOW_CTRL

    arr = Array.new(513) { |i| i.zero? ? 0 : 1 }
    ctx.set_line_property2(:bits_8, :stop_bit_2, :none, :break_on)
    sleep 0.001
    ctx.set_line_property2(:bits_8, :stop_bit_2, :none, :break_off)
    sleep 0.001
    ctx.write_data(arr)

    sleep 1

    arr = [ 0 ] * 513
    ctx.set_line_property2(:bits_8, :stop_bit_2, :none, :break_on)
    sleep 0.001
    ctx.set_line_property2(:bits_8, :stop_bit_2, :none, :break_off)
    sleep 0.001
    ctx.write_data(arr)

    puts "Context is:"
    ctx.members.each { |k| puts "#{k} = #{ctx[k]}" }

  ensure
    ctx.usb_close
  end
rescue Ftdi::Error => e
  $stderr.puts e.to_s
end
```

