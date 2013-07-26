# Wrap UUID creation on Windows
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'ffi'
require_relative 'winerror'

module UUID

  extend FFI::Library
  ffi_lib 'rpcrt4'
  ffi_convention :stdcall

  attach_function :UuidCreateSequential, [:pointer], :ulong

  module_function

  def create
    # Can't be bothered creating this:
    #
    # typedef struct _GUID {
    #   unsigned long  Data1;
    #   unsigned short Data2;
    #   unsigned short Data3;
    #   unsigned char  Data4[8];
    # } GUID, UUID;
    buf    = FFI::MemoryPointer.from_string( ' ' * 16 )
    retval = UuidCreateSequential buf
    raise "#{self}:#{__method__}: #{WinError.get_last_error}" unless retval.zero?
    ("%.2x%.2x-%.2x-%.2x-%.2x-%.2x%.2x%.2x" %  buf.read_array_of_uchar( 16 )).upcase
  end

end

