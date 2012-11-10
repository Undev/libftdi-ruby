#!/usr/bin/env ruby
require 'rubygems'
require 'ftdi'

ctx = Ftdi::Context.new

begin
  ctx.usb_open(0x0403, 0x6001)

  begin
    ctx.set_bitmode(0xff, :bitbang)
    #ctx.baudrate = 250000

    10.times do
      ctx.write_data [0xff]
      sleep 0.5
      ctx.write_data [0x00]
      sleep 0.5
    end
  ensure
    ctx.set_bitmode(0xff, :reset)
    ctx.usb_close
  end
rescue Ftdi::Error => e
  $stderr.puts e.to_s
end
