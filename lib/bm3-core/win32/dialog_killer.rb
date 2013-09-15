# Abstract the process of killing dialog boxes. Kills them
# until closed, for a given PID.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'ffi'
require 'bm3-core'

module BM3
  module Win32
    module Dialog

      # Window message constants etc
      BMCLICK         = 0x00F5
      WM_DESTROY      = 0x0010
      WM_COMMAND      = 0x111
      IDOK            = 1
      IDCANCEL        = 2
      IDNO            = 7
      IDCLOSE         = 8
      GW_ENABLEDPOPUP = 0x0006

      extend FFI::Library

      ffi_lib 'user32'
      ffi_convention :stdcall

      callback :enum_callback, [:ulong, :ulong], :bool
      attach_function :EnumDesktopWindows, [:pointer, :enum_callback, :ulong], :bool
      attach_function :PostMessageA, [:ulong, :int, :ulong, :ulong], :bool
      attach_function :GetWindowThreadProcessId, [:ulong, :pointer], :ulong
      attach_function :GetWindow, [:ulong, :int], :ulong

      def dialogs_killed?
        @dialogs_killed
      end

      def reset
        @dialogs_killed = false
      end

      def kill_dialogs target_pid
        @kill_popups ||= Proc.new {|handle, param|
          # This won't get ALL the windows, eg with Word it sometimes
          # pops up a toplevel dialog box that is not a popup of the
          # parent pid.
          pid = FFI::MemoryPointer.new :ulong
          GetWindowThreadProcessId handle, pid
          if pid.read_ulong == param
            # Window belongs to this pid
            # Does it have any popups?
            popup = GetWindow handle, GW_ENABLEDPOPUP
            unless popup.zero?
              @dialogs_killed = true
              PostMessageA popup, WM_COMMAND, IDCANCEL, 0
              PostMessageA popup, WM_COMMAND, IDNO, 0
              PostMessageA popup, WM_COMMAND, IDCLOSE, 0
              PostMessageA popup, WM_COMMAND, IDOK, 0
              PostMessageA popup, WM_DESTROY, 0, 0
            end
          end
          true # keep enumerating
        }
        EnumDesktopWindows( nil, @kill_popups, target_pid )
      end

    end

    class DialogKiller

      include Dialog
      extend Dialog
      include BM3::Logger

      def initialize sleeptime = 3, debug = false
        @sleeptime = sleeptime
        @debug     = debug
      end

      def start pid
        @pid = pid
        debug_info "Starting to kill dialogs for #{pid}"
        start_dk_thread pid
      end

      def stop
        return unless @dk_thread
        @dk_thread.kill
        @dk_thread = nil
        debug_info "No longer killing dialogs for #{@pid}"
      end

      private

      def start_dk_thread pid
        # This might be leaky on JRuby on Win7 x64 when used within another
        # Thread, so you you're seeing handle / USER object leaks, add it to your
        # list of suspects. The workaround is to repeatedly just call the
        # kill_dialogs method.
        @dk_thread = Thread.new do
          loop do
            begin
              kill_dialogs pid
              sleep @sleeptime
            rescue
              sleep @sleeptime
              debug_info "Error in DK thread: #{$!}"
              retry
            end
          end
        end
      end
    end
  end
end
