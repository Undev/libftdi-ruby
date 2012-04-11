require 'ffi'
require "ftdi/version"

module Ftdi
  extend FFI::Library

  ffi_lib "libftdi"

  # FTDI chip type.
  ChipType = enum(:type_am, :type_bm, :type_2232c, :type_r, :type_2232h, :type_4232h, :type_232h)

  # Automatic loading / unloading of kernel modules
  ModuleDetachMode = enum(:auto_detach_sio_module, :dont_detach_sio_module)

  # Number of bits for {Ftdi::Context.set_line_property}
  BitsType = enum(
    :bits_7, 7,
    :bits_8, 8
  )

  # Number of stop bits for {Ftdi::Context.set_line_property}
  StopbitsType = enum(
    :stop_bit_1, 0,
    :stop_bit_15, 1,
    :stop_bit_2, 2
  )

  # Parity mode for {Ftdi::Context.set_line_property}
  ParityType = enum(:none, :odd, :even, :mark, :space)

  # Break type for {Ftdi::Context.set_line_property2}
  BreakType = enum(:break_off, :break_on)

  SIO_DISABLE_FLOW_CTRL = 0x0

  # Base error
  class Error < RuntimeError; end

  # Initialization error
  class CannotInitializeContextError < Error; end

  # Error with libftdi status code
  class StatusCodeError < Error
    attr_accessor :status_code

    def initialize(status_code, message)
      super(message)
      self.status_code = status_code
    end

    def to_s
      "#{status_code}: #{super}"
    end
  end

  # Context
  class Context < FFI::Struct
    layout(
      # USB specific
      # libusb's context
      :usb_ctx, :pointer,
      # libusb's usb_dev_handle
      :usb_dev, :pointer,
      # usb read timeout
      :usb_read_timeout, :int,
      # usb write timeout
      :usb_write_timeout, :int,

      # FTDI specific
      # FTDI chip type
      :type, Ftdi::ChipType,
      # baudrate
      :baudrate, :int,
      # bitbang mode state
      :bitbang_enabled, :uint8,
      # pointer to read buffer for ftdi_read_data
      :readbuffer, :pointer,
      # read buffer offset
      :readbuffer_offset, :uint,
      # number of remaining data in internal read buffer
      :readbuffer_remaining, :uint,
      # read buffer chunk size
      :readbuffer_chunksize, :uint,
      # write buffer chunk size
      :writebuffer_chunksize, :uint,
      # maximum packet size. Needed for filtering modem status bytes every n packets.
      :max_packet_size, :uint,

      # FTDI FT2232C requirements
      # FT2232C interface number: 0 or 1
      :interface, :int, # 0 or 1
      # FT2232C index number: 1 or 2
      :index, :int, # 1 or 2
      # Endpoints
      # FT2232C end points: 1 or 2
      :in_ep, :int,
      :out_ep, :int, # 1 or 2

      # Bitbang mode. 1: (default) Normal bitbang mode, 2: FT2232C SPI bitbang mode
      :bitbang_mode, :uint8,

      # Decoded eeprom structure
      :eeprom, :pointer,

      # String representation of last error
      :error_str, :string,

      # Defines behavior in case a kernel module is already attached to the device
      :module_detach_mode, Ftdi::ModuleDetachMode
    )

    def initialize
      ptr = Ftdi.ftdi_new
      raise CannotInitializeContextError.new  if ptr.nil?
      super(ptr)
    end

    def ctx
      self.to_ptr
    end

    # Deinitialize and free an ftdi context.
    def dispose
      Ftdi.ftdi_free(ctx)
      nil
    end

    alias :close :dispose

    def error_string
      self[:error_str]
    end

    def check_result(status_code)
      if status_code < 0
        raise StatusCodeError.new(status_code, error_string)
      end
      nil
    end

    # Opens the first device with a given vendor and product ids.
    def usb_open(vendor, product)
      raise ArgumentError.new('vendor should be Fixnum')  unless vendor.kind_of?(Fixnum)
      raise ArgumentError.new('product should be Fixnum')  unless product.kind_of?(Fixnum)
      check_result(Ftdi.ftdi_usb_open(ctx, vendor, product))
    end

    # Closes the ftdi device.
    def usb_close
      Ftdi.ftdi_usb_close(ctx)
      nil
    end

    # Gets the chip baud rate.
    def baudrate
      self[:baudrate]
    end

    # Sets the chip baud rate.
    def baudrate=(new_baudrate)
      raise ArgumentError.new('baudrate should be Fixnum')  unless new_baudrate.kind_of?(Fixnum)
      check_result(Ftdi.ftdi_set_baudrate(ctx, new_baudrate))
    end

    # Set (RS232) line characteristics.
    # The break type can only be set via {#set_line_property2} and defaults to "off".
    def set_line_property(bits, stopbits,  parity)
      check_result(Ftdi.ftdi_set_line_property(ctx, bits, stopbits, parity))
    end

    # Set (RS232) line characteristics.
    def set_line_property2(bits, stopbits,  parity, _break)
      check_result(Ftdi.ftdi_set_line_property2(ctx, bits, stopbits, parity, _break))
    end

    # Set flowcontrol for ftdi chip.
    def flowctrl=(new_flowctrl)
      check_result(Ftdi.ftdi_setflowctrl(ctx, new_flowctrl))
    end

    def write_data(bytes)
      size = bytes.respond_to?(:bytesize) ? bytes.bytesize : bytes.size
      mem_buf = FFI::MemoryPointer.new(:char, size)
      mem_buf.put_bytes(0, bytes)
      check_result(Ftdi.ftdi_write_data(ctx, mem_buf, size))
    end
  end

  attach_function :ftdi_new, [ ], :pointer
  attach_function :ftdi_free, [ :pointer ], :void
  attach_function :ftdi_usb_open, [ :pointer, :int, :int ], :int
  attach_function :ftdi_usb_close, [ :pointer ], :void
  attach_function :ftdi_set_baudrate, [ :pointer, :int ], :int
  attach_function :ftdi_set_line_property, [ :pointer, BitsType, StopbitsType, ParityType ], :int
  attach_function :ftdi_set_line_property2, [ :pointer, BitsType, StopbitsType, ParityType, BreakType ], :int
  attach_function :ftdi_setflowctrl, [ :pointer, :int ], :int
  attach_function :ftdi_write_data, [ :pointer, :pointer, :int ], :int
end

