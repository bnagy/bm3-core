# This class offers two ways to monitor the approximate CPU utilisation
# of a target process. The general approach is to divide the increase
# in process kernel/userland time with the increase in the overall system
# time.
#
# You can either just call #update_rolling_avg whenever you want, and manage
# your own timing, calling #rolling_avg to check the results, or call
# less_than_threshold? which will block for around nper * granularity seconds,
# and then return a boolean to you.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'rubygems'
require_relative 'winerror'

module BM3
  module Win32
    module ProcessTimes

      PROCESS_QUERY_INFORMATION = 0x0400
      PROCESS_VM_READ = 0x0010

      extend FFI::Library
      ffi_lib 'kernel32'
      ffi_convention :stdcall

      attach_function :close_handle, :CloseHandle, [:ulong], :ulong
      attach_function :open_process, :OpenProcess, [:ulong, :bool, :ulong], :ulong
      attach_function :get_process_times, :GetProcessTimes, [:ulong, :pointer, :pointer, :pointer, :pointer], :ulong
      attach_function :get_system_times, :GetSystemTimes, [:pointer, :pointer, :pointer], :ulong

    end

    class CPUMonitor

      COMPONENT="CPUMonitor"
      VERSION="2.0.0"

      def raise_win32_error( meth )
        raise "#{COMPONENT}:#{VERSION}:#{meth} Win32 Exception: #{WinError.get_last_error}"
      end

      def initialize( pid, thresh=0, nper=15, granularity=1 )
        @pid,@thresh,@nper,@granularity=pid, thresh, nper, granularity
        @times=[]
        retries=5
        loop do
          @hProcess=ProcessTimes.open_process(
            ProcessTimes::PROCESS_QUERY_INFORMATION|ProcessTimes::PROCESS_VM_READ,
            false,
            @pid
          )
          if @hProcess.zero?
            sleep 0.5
            redo if (retries-=1) <=0
            raise_win32_error __method__
          else
            break
          end
        end
      end

      def update_rolling_avg
        # timing agnostic.
        proc_k_now, proc_u_now, sys_k_now, sys_u_now = get_times( @hProcess )
        if @proc_k_then
          proc_total_diff = (proc_u_now - @proc_u_then + proc_k_now - @proc_k_then)
          sys_total_diff = (sys_u_now - @sys_u_then + sys_k_now - @sys_k_then)
          @time=(proc_total_diff.to_f / sys_total_diff.to_f)*100
          unless @time.nan? # if there has been no sys increase at all, it's a divzero.
            @times << @time
          else
            @times << 0.0
          end
        end
        @proc_k_then, @proc_u_then, @sys_k_then, @sys_u_then=proc_k_now, proc_u_now, sys_k_now, sys_u_now
      end

      def rolling_avg( nper )
        return nil if @times.size < nper
        @times.last( nper ).inject {|s,n| s+=n} / nper
      end

      def any_above?( lim )
        @times.any? {|time| time > lim}
      end

      def clear_rolling_avg
        @times.clear
      end

      def less_than_threshold?
        # Blocks for nper * granularity seconds (give or take, sleep is not exact)
        # Just returns a boolean
        percents=[]
        @nper.times do
          proc_k_then, proc_u_then, sys_k_then, sys_u_then = get_times( @hProcess )
          sleep @granularity
          proc_k_now, proc_u_now, sys_k_now, sys_u_now = get_times( @hProcess )
          proc_total_diff = (proc_u_now - proc_u_then + proc_k_now - proc_k_then)
          sys_total_diff = (sys_u_now - sys_u_then + sys_k_now - sys_k_then)
          percents << (proc_total_diff.to_f / sys_total_diff.to_f)*100
        end
        average=percents.inject {|s,n| s+=n} / percents.size
        average < @thresh
      end

      def close
        # Make sure to call close, or it will leak process handles.
        ProcessTimes.close_handle @hProcess
      end

      private

        def get_times( hProcess )
          # Return the current kernel and user times for the system and the specified hProcess
          # Uses a ghetto version of a FILETIME struct, which is converted into a quadword.
          create_time,exit_time,ktime,utime=Array.new(4) { p_ulong_long }
          raise_win32_error( __method__ ) if ProcessTimes.get_process_times( hProcess, create_time, exit_time, ktime, utime ).zero?
          sys_itime,sys_ktime,sys_utime=Array.new(3) { p_ulong_long }
          raise_win32_error( __method__ ) if ProcessTimes.get_system_times( sys_itime, sys_ktime, sys_utime ).zero?
          [ktime, utime, sys_ktime, sys_utime].map {|ptr| ptr.read_ulong_long}
        end

        def p_ulong_long
          FFI::MemoryPointer.new :ulong_long
        end

    end
  end
end
