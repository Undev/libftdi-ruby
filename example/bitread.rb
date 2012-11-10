#!/usr/bin/env ruby
require 'rubygems'
require './ftdi'

ctx = Ftdi::Context.new

begin
  ctx.usb_open(0x0403, 0x6001)

  begin
    ctx.set_bitmode(0x00, :bitbang)
    #ctx.baudrate = 250000

    100.times do
      p ctx.read_pins
      sleep 0.5
    end
  ensure
    ctx.set_bitmode(0x00, :reset)
    ctx.usb_close
  end
rescue Ftdi::Error => e
  $stderr.puts e.to_s
end
