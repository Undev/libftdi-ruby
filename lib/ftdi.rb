require 'ffi'
require "ftdi/version"

# Represents libftdi ruby bindings.
# End-user API represented by {Ftdi::Context} class.
module Ftdi
  extend FFI::Library

  ffi_lib "libftdi"

  # FTDI chip type.
  ChipType = enum(:type_am, :type_bm, :type_2232c, :type_r, :type_2232h, :type_4232h, :type_232h)

  # Automatic loading / unloading of kernel modules.
  ModuleDetachMode = enum(:auto_detach_sio_module, :dont_detach_sio_module)

  # Number of bits for {Ftdi::Context#set_line_property}.
  BitsType = enum(
    :bits_7, 7,
    :bits_8, 8
  )

  # Number of stop bits for {Ftdi::Context#set_line_property}.
  StopbitsType = enum(
    :stop_bit_1, 0,
    :stop_bit_15, 1,
    :stop_bit_2, 2
  )

  # Parity mode for {Ftdi::Context#set_line_property}.
  ParityType = enum(:none, :odd, :even, :mark, :space)

  # Break type for {Ftdi::Context#set_line_property2}.
  BreakType = enum(:break_off, :break_on)

  # Port interface for chips with multiple interfaces.
  # @see Ftdi::Context#interface=
  Interface = enum(:interface_any, :interface_a, :interface_b, :interface_c, :interface_d)

  # Bitbang mode for {Ftdi::Context#set_bitmode}.
  BitbangMode = enum(:reset, :bitbang, :mpsse, :syncbb, :mcu, :opto, :cbus, :syncff)

  # Flow control: disable
  # @see Ftdi::Context#flowctrl=
  SIO_DISABLE_FLOW_CTRL = 0x0
  # @see Ftdi::Context#flowctrl=
  SIO_RTS_CTS_HS        = (0x1 << 8)
  # @see Ftdi::Context#flowctrl=
  SIO_DTR_DSR_HS        = (0x2 << 8)
  # @see Ftdi::Context#flowctrl=
  SIO_XON_XOFF_HS       = (0x4 << 8)

  # Base error of libftdi.
  class Error < RuntimeError; end

  # Represents initialization error of libftdi.
  class CannotInitializeContextError < Error; end

  # Represents error of libftdi with its status code.
  class StatusCodeError < Error
    # Gets status code.
    # @return [Fixnum] Status code.
    attr_reader :status_code

    def initialize(status_code, message)
      super(message)
      @status_code = status_code
    end

    # Gets string representation of the error.
    # @return [String] Representation of the error.
    def to_s
      "#{status_code}: #{super}"
    end
  end

  # Represents libftdi context and end-user API.
  # @example Open USB device
  #   ctx = Ftdi::Context.new
  #   begin
  #     ctx.usb_open(0x0403, 0x6001)
  #     begin
  #       ctx.baudrate = 250000
  #     ensure
  #      ctx.usb_close
  #     end
  #   rescue Ftdi::Error => e
  #     $stderr.puts e.to_s
  #   end
  class Context < FFI::ManagedStruct
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

    # Initializes new libftdi context.
    # @raise [CannotInitializeContextError] libftdi cannot be initialized.
    def initialize
      ptr = Ftdi.ftdi_new
      raise CannotInitializeContextError.new  if ptr.nil?
      super(ptr)
    end

    # Deinitialize and free an ftdi context.
    # @return [NilClass] nil
    def self.release(p)
      Ftdi.ftdi_free(p)
      nil
    end

    # Gets error text.
    # @return [String] Error text.
    def error_string
      self[:error_str]
    end

    # Opens the first device with a given vendor and product ids.
    # @param [Fixnum] vendor Vendor id.
    # @param [Fixnum] product Product id.
    # @return [NilClass] nil
    # @raise [StatusCodeError] libftdi reports error.
    # @raise [ArgumentError] Bad arguments.
    def usb_open(vendor, product)
      raise ArgumentError.new('vendor should be Fixnum')  unless vendor.kind_of?(Fixnum)
      raise ArgumentError.new('product should be Fixnum')  unless product.kind_of?(Fixnum)
      check_result(Ftdi.ftdi_usb_open(ctx, vendor, product))
    end

    # Opens the first device with a given vendor and product ids, description and serial.
    # @param [Fixnum] vendor Vendor id.
    # @param [Fixnum] product Product id.
    # @param [String] description Description to search for. Use nil if not needed.
    # @param [String] serial Serial to search for. Use nil if not needed.
    # @return [NilClass] nil
    # @raise [StatusCodeError] libftdi reports error.
    # @raise [ArgumentError] Bad arguments.
    def usb_open_desc(vendor, product, description, serial)
      raise ArgumentError.new('vendor should be Fixnum')  unless vendor.kind_of?(Fixnum)
      raise ArgumentError.new('product should be Fixnum')  unless product.kind_of?(Fixnum)
      check_result(Ftdi.ftdi_usb_open_desc(ctx, vendor, product, description, serial))
    end

    # Opens the index-th device with a given vendor and product ids, description and serial.
    # @param [Fixnum] vendor Vendor id.
    # @param [Fixnum] product Product id.
    # @param [String] description Description to search for. Use nil if not needed.
    # @param [String] serial Serial to search for. Use nil if not needed.
    # @param [Fixnum] index Number of matching device to open if there are more than one, starts with 0.
    # @return [NilClass] nil
    # @raise [StatusCodeError] libftdi reports error.
    # @raise [ArgumentError] Bad arguments.
    def usb_open_desc_index(vendor, product, description, serial, index)
      raise ArgumentError.new('vendor should be Fixnum')  unless vendor.kind_of?(Fixnum)
      raise ArgumentError.new('product should be Fixnum')  unless product.kind_of?(Fixnum)
      raise ArgumentError.new('index should be Fixnum')  unless index.kind_of?(Fixnum)
      raise ArgumentError.new('index should be greater than or equal to zero')  if index < 0
      check_result(Ftdi.ftdi_usb_open_desc_index(ctx, vendor, product, description, serial, index))
    end

    # Resets the ftdi device.
    # @raise [StatusCodeError] libftdi reports error.
    # @return [NilClass] nil
    def usb_reset
      check_result(Ftdi.ftdi_usb_reset(ctx))
    end

    # Closes the ftdi device.
    # @return [NilClass] nil
    def usb_close
      Ftdi.ftdi_usb_close(ctx)
      nil
    end

    # Gets the chip baud rate.
    # @return [Fixnum] Baud rate.
    def baudrate
      self[:baudrate]
    end

    # Sets the chip baud rate.
    # @raise [StatusCodeError] libftdi reports error.
    # @raise [ArgumentError] Bad arguments.
    # @return [NilClass] nil
    def baudrate=(new_baudrate)
      raise ArgumentError.new('baudrate should be Fixnum')  unless new_baudrate.kind_of?(Fixnum)
      check_result(Ftdi.ftdi_set_baudrate(ctx, new_baudrate))
    end

    # Set (RS232) line characteristics.
    # The break type can only be set via {#set_line_property2} and defaults to "off".
    # @param [BitsType] bits
    # @param [StopbitsType] stopbits
    # @param [ParityType] parity
    # @raise [StatusCodeError] libftdi reports error.
    # @return [NilClass] nil
    def set_line_property(bits, stopbits,  parity)
      check_result(Ftdi.ftdi_set_line_property(ctx, bits, stopbits, parity))
    end

    # Set (RS232) line characteristics.
    # @param [BitsType] bits
    # @param [StopbitsType] stopbits
    # @param [ParityType] parity
    # @param [BreakType] _break
    # @raise [StatusCodeError] libftdi reports error.
    # @return [NilClass] nil
    def set_line_property2(bits, stopbits,  parity, _break)
      check_result(Ftdi.ftdi_set_line_property2(ctx, bits, stopbits, parity, _break))
    end

    # Set flow control setting for ftdi chip.
    # @param [Fixnum] new_flowctrl New flow control setting.
    # @raise [StatusCodeError] libftdi reports error.
    # @return [Fixnum] New flow control setting.
    # @see SIO_DISABLE_FLOW_CTRL
    # @see SIO_RTS_CTS_HS
    # @see SIO_DTR_DSR_HS
    # @see SIO_XON_XOFF_HS
    def flowctrl=(new_flowctrl)
      check_result(Ftdi.ftdi_setflowctrl(ctx, new_flowctrl))
      new_flowctrl
    end

    # Set Bitbang mode for ftdi chip.
    # @param [Fixnum] bitmask to configure lines. HIGH/ON value configures a line as output.
    # @param [BitbangMode] mode Bitbang mode: use the values defined in {Ftdi::Context#BitbangMode}
    # @return [NilClass] nil
    # @see BitbangMode
    def set_bitmode(bitmask, mode)
      check_result(Ftdi.ftdi_set_bitmode(ctx, bitmask, mode))
    end

    # Gets write buffer chunk size.
    # @return [Fixnum] Write buffer chunk size.
    # @raise [StatusCodeError] libftdi reports error.
    # @see #write_data_chunksize=
    def write_data_chunksize
      p = FFI::MemoryPointer.new(:uint, 1)
      check_result(Ftdi.ftdi_write_data_get_chunksize(ctx, p))
      p.read_uint
    end

    # Configure write buffer chunk size.
    # Automatically reallocates the buffer.
    # @note Default is 4096.
    # @param [Fixnum] new_chunksize Write buffer chunk size.
    # @return [Fixnum] New write buffer chunk size.
    # @raise [StatusCodeError] libftdi reports error.
    def write_data_chunksize=(new_chunksize)
      check_result(Ftdi.ftdi_write_data_set_chunksize(ctx, new_chunksize))
      new_chunksize
    end

    # Writes data.
    # @param [String, Array] bytes String or array of integers that will be interpreted as bytes using pack('c*').
    # @return [Fixnum] Number of written bytes.
    # @raise [StatusCodeError] libftdi reports error.
    def write_data(bytes)
      bytes = bytes.pack('c*')  if bytes.respond_to?(:pack)
      size = bytes.respond_to?(:bytesize) ? bytes.bytesize : bytes.size
      mem_buf = FFI::MemoryPointer.new(:char, size)
      mem_buf.put_bytes(0, bytes)
      bytes_written = Ftdi.ftdi_write_data(ctx, mem_buf, size)
      check_result(bytes_written)
      bytes_written
    end

    # Gets read buffer chunk size.
    # @return [Fixnum] Read buffer chunk size.
    # @raise [StatusCodeError] libftdi reports error.
    # @see #read_data_chunksize=
    def read_data_chunksize
      p = FFI::MemoryPointer.new(:uint, 1)
      check_result(Ftdi.ftdi_read_data_get_chunksize(ctx, p))
      p.read_uint
    end

    # Configure read buffer chunk size.
    # Automatically reallocates the buffer.
    # @note Default is 4096.
    # @param [Fixnum] new_chunksize Read buffer chunk size.
    # @return [Fixnum] New read buffer chunk size.
    # @raise [StatusCodeError] libftdi reports error.
    def read_data_chunksize=(new_chunksize)
      check_result(Ftdi.ftdi_read_data_set_chunksize(ctx, new_chunksize))
      new_chunksize
    end

    # Reads data in chunks from the chip.
    # Returns when at least one byte is available or when the latency timer has elapsed.
    # Automatically strips the two modem status bytes transfered during every read.
    # @return [String] Bytes read; Empty string if no bytes read.
    # @see #read_data_chunksize
    # @raise [StatusCodeError] libftdi reports error.
    def read_data
      chunksize = read_data_chunksize
      p = FFI::MemoryPointer.new(:char, chunksize)
      bytes_read = Ftdi.ftdi_read_data(ctx, p, chunksize)
      check_result(bytes_read)
      r = p.read_bytes(bytes_read)
      r.force_encoding("ASCII-8BIT")  if r.respond_to?(:force_encoding)
      r
    end

    # Directly read pin state, circumventing the read buffer. Useful for bitbang mode.
    # @return [Fixnum] Pins state
    # @raise [StatusCodeError] libftdi reports error.
    # @see #set_bitmode
    def read_pins
      p = FFI::MemoryPointer.new(:uchar, 1)
      check_result(Ftdi.ftdi_read_pins(ctx, p))
      p.read_uchar
    end

    # Gets used interface of the device.
    # @return [Interface] Used interface of the device.
    def interface
      Interface[self[:interface]]
    end

    # Open selected channels on a chip, otherwise use first channel.
    # @param [Interface] new_interface Interface to use for FT2232C/2232H/4232H chips.
    # @raise [StatusCodeError] libftdi reports error.
    # @return [Interface] New interface.
    def interface=(new_interface)
      check_result(Ftdi.ftdi_set_interface(ctx, new_interface))
      new_interface
    end

  private
    def ctx
      self.to_ptr
    end

    def check_result(status_code)
      if status_code < 0
        raise StatusCodeError.new(status_code, error_string)
      end
      nil
    end
  end

  attach_function :ftdi_new, [ ], :pointer
  attach_function :ftdi_free, [ :pointer ], :void
  attach_function :ftdi_usb_open, [ :pointer, :int, :int ], :int
  attach_function :ftdi_usb_open_desc, [ :pointer, :int, :int, :string, :string ], :int
  attach_function :ftdi_usb_open_desc_index, [ :pointer, :int, :int, :string, :string, :uint ], :int
  attach_function :ftdi_usb_reset, [ :pointer ], :int
  attach_function :ftdi_usb_close, [ :pointer ], :void
  attach_function :ftdi_set_baudrate, [ :pointer, :int ], :int
  attach_function :ftdi_set_line_property, [ :pointer, BitsType, StopbitsType, ParityType ], :int
  attach_function :ftdi_set_line_property2, [ :pointer, BitsType, StopbitsType, ParityType, BreakType ], :int
  attach_function :ftdi_setflowctrl, [ :pointer, :int ], :int
  attach_function :ftdi_write_data, [ :pointer, :pointer, :int ], :int
  attach_function :ftdi_write_data_set_chunksize, [ :pointer, :uint ], :int
  attach_function :ftdi_write_data_get_chunksize, [ :pointer, :pointer ], :int
  attach_function :ftdi_read_data, [ :pointer, :pointer, :int ], :int
  attach_function :ftdi_read_data_set_chunksize, [ :pointer, :uint ], :int
  attach_function :ftdi_read_data_get_chunksize, [ :pointer, :pointer ], :int
  attach_function :ftdi_set_interface, [ :pointer, Interface ], :int
  attach_function :ftdi_set_bitmode, [ :pointer,  :int,  :int ], :int
  attach_function :ftdi_read_pins, [ :pointer,  :pointer ], :int
end

