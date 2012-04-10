require 'ffi'
require "ftdi/version"

module Ftdi
  extend FFI::Library

  ffi_lib "libftdi"

  # FTDI chip type.
  ChipType = enum(:type_am, :type_bm, :type_2232c, :type_r, :type_2232h, :type_4232h, :type_232h)

  # Automatic loading / unloading of kernel modules
  ModuleDetachMode = enum(:auto_detach_sio_module, :dont_detach_sio_module)

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

    def error_string
      self[:error_str]
    end

    # Opens the first device with a given vendor and product ids.
    def usb_open(vendor, product)
      Ftdi.usb_open(self, vendor, product)
    end

    # Closes the ftdi device.
    def usb_close
      Ftdi.usb_close(self)
    end

    # Allocate and initialize a new ftdi context
    def self.open
      Ftdi.init
    end

    # Deinitialize and free an ftdi context.
    def close
      Ftdi.deinit(self)
    end
  end

  attach_function :ftdi_new, [ ], :pointer
  attach_function :ftdi_free, [ :pointer ], :void
  attach_function :ftdi_usb_open, [ :pointer, :int, :int ], :int

  class << self
    # Allocate and initialize a new ftdi_context
    def init
      r = ftdi_new
      raise CannotInitializeContextError.new  if r.nil?

      Context.new(r)
    end

    def check_context(context)
      raise ArgumentError.new("context is nil")  if context.nil?
    end

    def raise_error(status_code, context)
      raise StatusCodeError.new(status_code, context.error_string)
    end

    # Deinitialize and free an ftdi context.
    def deinit(context)
      check_context(context)

      ftdi_free(context.to_ptr)
    end

    # Opens the first device with a given vendor and product ids.
    def usb_open(context, vendor, product)
      check_context(context)
      r = ftdi_usb_open(context.to_ptr, vendor, product)
      unless r.zero?
        raise_error(r, context)
      end
    end

    # Closes the ftdi device.
    def usb_close(context)
      check_context(context)
      r = ftdi_usb_close(context.to_ptr)
      unless r.zero?
        raise_error(r, context)
      end
    end
  end
end

