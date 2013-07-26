# Abstraction for storing and retrieving bugs from disk, to make component
# interop easier
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require_relative 'bug/detail_parser'
require 'yaml'

module BM3
  class Bug

    COMPONENT = "Bug"
    VERSION   = "1.1.0"

    attr_reader :detail, :id, :pdu

    def initialize pdu
      @pdu    = pdu
      @detail = Detail.new pdu['exception_info']
      @id     = pdu['tag']['fuzzbot_crash_uuid']
    end

    def self.from_file fname
      # Call this method with the data file of the bug (the file that crashes the
      # app, not a metadata file).
      unless File.exists?( full_fname=File.expand_path(fname) )
        raise ArgumentError, "#{COMPONENT}-#{VERSION}: Can't find filename #{fname}"
      end
      dir = File.dirname full_fname
      id  = File.basename full_fname, File.extname( full_fname )
      pdu = Hash.new {|h,k|
        # be lazy about loading the data to save IO if this class is only being
        # used for analysis
        case k
        when 'data'
          h[k] = File.binread full_fname
        when 'dump'
          if File.exists? File.join(dir, "#{id}.dmp")
            h[k] = File.binread File.join(dir, "#{id}.dmp")
          else
            h[k] = ''
          end
        else
          nil
        end
      }
      pdu['tag']            = YAML.load_file File.join(dir, "#{id}.tag")
      pdu['exception_info'] = File.binread File.join(dir, "#{id}.txt")
      self.new pdu
    end

    def summary
      output = ""
      begin
        output << "#{@detail.short_desc} (#{@detail.classification})\n\n"
        output << "==Disassembly\n\n"
        output << "#{@detail.disassembly[1..-1].join("\n") rescue '<disassembly failed>'}"
        output << "\n\n"
        output << "==Stack\n\n"
        output << @detail.stack_trace[0..4].join("\n") rescue '<stacktrace failed>'
        output << "\n\n"
        output <<  "==Registers\n\n"
        output << "#{@detail.registers.map {|k,v| "#{k}:#{v}"}.join(' ')}\n\n"
      rescue
        "I BROKE THE PARSER!"
      end
    end

    def short_summary
      "#{@detail.long_desc} #{@detail.disassembly[1].squeeze(' ')} (#{@detail.hash})"
    end

    def dump output_dir
      unless File.directory?( full_dir=File.expand_path(output_dir) )
        raise ArgumentError, "#{COMPONENT}-#{VERSION}: Bad output directory #{output_dir}"
      end
      File.binwrite File.join(full_dir,"#{@id}.tag"), YAML.dump(@pdu['tag'])
      File.binwrite File.join(full_dir,"#{@id}.txt"), @pdu['exception_info']
      File.binwrite(
        File.join(full_dir,"#{@id}.#{@pdu['tag']['fuzzbot_extension']}"),
        @pdu['data']
      )
      unless @pdu['dump'].empty?
        File.binwrite File.join(full_dir,"#{@id}.dmp"), @pdu['dump']
      end
    end

  end
end
