# Some code to parse crash detail files, mainly focused on the machine
# parseable output of !exploitable.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'date'

module BM3
  module DetailParser

    # In: the !exploitable output as a string
    # Out: [[0, "wwlib!wdCommandDispatch+0x14509b"], [1, ... etc
    def self.stack_trace detail_string
      frames = detail_string.scan( /^STACK_FRAME:(.*)$/ ).flatten
      (0..frames.length-1).to_a.zip frames
    end

    # In: the debugger output as a string - assumes you have run 'lm -v'
    # Out: a hash of (Integer) module_base => [(Boolean) syms_loaded, detail_hsh]
    # where detail_hsh has the !exploitable output as a string) :name,
    # (Integer) :size, (String) :version, (Integer) :checksum.
    def self.loaded_modules detail_string
      # Module entries look like this in the file:
      # Note that the stuff in brackets can be "export symbols"
      # "pdb symbols" or "deferred" if the symbols weren't loaded yet.
      # 01ff0000 022b5000   xpsp2res   (deferred)
      #    Image path: C:\WINDOWS\system32\xpsp2res.dll
      #    Image name: xpsp2res.dll
      #    Timestamp:        Mon Apr 14 01:39:24 2008 (4802454C)
      #    CheckSum:         002CA420
      #    ImageSize:        002C5000
      #    File version:     5.1.2600.5512
      #    [... etc ...]
      # Take the image base and symbol status from the first line
      # then grab all the key : value stuff as one big chunk, until the
      # next header line which is the zero-width lookahead (?=
      barf = detail_string.scan(/([0-9a-f]{8}) [0-9a-f]{8}.+?\((.*?)\).+?$(.+?)(?=[0-9a-f]{8} [0-9a-f]{8})/m)
      # Now take the !exploitable output as a string pairs
      barf = barf.map {|a| [a[0],a[1],a[2].scan(/^\s+(\S.+):\s+(\S.+)$/)]}
      # Take the !exploitable output as a string pairs and turn them into a hash
      barf = barf.map {|a| [ a[0], a[1], Hash[*a[2].flatten] ] }
      # Now we have ["01ff0000", "export symbols", {"Image path"=>"C:\\WINDOWS\\ ... etc
      # Unloaded modules entries don't have an image name. Remove them.
      barf = barf.select {|a| a[2].has_key? "Image name"}
      final_result = {}
      barf.each {|a|
        old_hsh                     = a[2]
        clean_results               = {}
        clean_results[:timestamp]   = DateTime.parse(old_hsh["Timestamp"])
        clean_results[:size]        = old_hsh["ImageSize"].to_i(16)
        clean_results[:name]        = old_hsh["Image name"].downcase
        clean_results[:checksum]    = old_hsh["CheckSum"].to_i(16)
        clean_results[:version]     = old_hsh["File version"].downcase
        final_result[a[0].to_i(16)] = [!!(a[1]=~/pdb/), clean_results]
      }
      final_result
    end

    # In: the !exploitable output as a string
    # Out: [[0, "316c5a0e mov eax,dword ptr [eax]"], [1,
    def self.disassembly detail_string
      # This is tied to the current debugger output style, which is a bit crap
      # the DISASSEMBLY_START / END tags are inserted by my analysis module
      instructions = detail_string.match(/DISASSEMBLY_START\n(.*?)^DISASSEMBLY_END/m)[1].split("\n")
      [*(0 ... instructions.length)].zip instructions
    rescue
      []
    end

    def self.faulting_instruction detail_string
      detail_string.match(/^INSTRUCTION_ADDRESS:(.*)$/)[1]
    rescue
      ""
    end


    # In: the !exploitable output as a string
    # Out: [["eax", "00000000"], ["ebx", ... etc
    def self.registers detail_string
      # *? is non-greedy, m is multiline. We take the !exploitable output as a
      # string because if there is more than one the first one will be from the
      # initial breakpoint
      detail_string.scan(/^[er]ax.*?iopl/m).last.scan(/([er].+?)=([0-9a-f]+)/)
    rescue
      []
    end

    # In: the !exploitable output as a string
    # Out: Long bug description, eg "Data from Faulting Address controls
    # Branch Selection"
    def self.long_desc detail_string
      detail_string.match(/^BUG_TITLE:(.*)$/)[1]
    rescue
      if detail_string =~ /UEF_HIT/
        "Exploitable - Unhandled Exception Filter hit " <<
          "#{detail_string.match(/^UEF_HIT:(.*)$/)[1].split.last}"
      else
        "<msec unavailable>"
      end
    end

    def self.short_desc detail_string
      detail_string.match(/^DESCRIPTION:(.*)$/)[1]
    rescue
      "<msec unavailable>"
    end
    # In: the !exploitable output as a string
    # Out: !exploitable classification, "UNKNOWN", "PROBABLY EXPLOITABLE" etc
    def self.classification detail_string
      classif = detail_string.match(/^CLASSIFICATION:(.*)$/)[1].tr('_',' ')
      # !exploitable at the UEF hook reports NOT_AN_EXCEPTION, but if
      # we have determined it's a /GS fault then we put it in the top
      # triage tier
      classif = "EXPLOITABLE" if detail_string=~/UEF_HIT/
      classif
    rescue
      "<msec unavailable>"
    end

    # In: the !exploitable output as a string
    # Out: !exploitable exception type, "STATUS_ACCESS_VIOLATION" etc
    def self.exception_type detail_string
      detail_string.match(/^EXCEPTION_TYPE:(.*)$/)[1]
    rescue
      ""
    end

    # In: the !exploitable output as a string
    # Out: !exploitable exception subtype, "READ" or "WRITE" etc
    def self.exception_subtype detail_string
      detail_string.match(/^EXCEPTION_SUBTYPE:(.*)$/)[1]
    rescue
      ""
    end

    def self.major_hash detail_string
      detail_string.match(/MAJOR_HASH:(.*)$/)[1]
    rescue
      ""
    end

    def self.minor_hash detail_string
      detail_string.match(/MINOR_HASH:(.*)$/)[1]
    rescue
      ""
    end

    # In: the !exploitable output as a string
    # Out: !exploitable Hash as a string eg "0x6c4b4441.0x1b792103"
    def self.hash detail_string
      maj = detail_string.match(/MAJOR_HASH:(.*)$/)[1]
      min = detail_string.match(/MINOR_HASH:(.*)$/)[1]
      "#{maj}.#{min}"
    rescue
      begin
        detail_string.match(/Hash=(.*)\)/)[1]
      rescue
        "<msec unavailable>"
      end
    end

  end

  # Quick wrapper class, for more complex, OO analysis

  class RegisterSet < Hash

    def method_missing meth, *args
      self[String(meth)]
    end

  end

  class Detail < BasicObject

    attr_reader :registers
    include ::BM3

    def initialize detail_string
      @detail_string = detail_string
      @registers     = RegisterSet[*(DetailParser.registers(@detail_string).flatten)]
    end

    def disassembly
      @disassembly ||= DetailParser.disassembly( @detail_string ).map {|a| a[1]} rescue nil
    end

    def stack_trace
      @stack_trace ||= DetailParser.stack_trace( @detail_string ).map {|a| a[1]} rescue nil
    end

    def affected_registers
      if @affected
        @affected
      else
        # This is unsound. Supposed to deal with x86 / x64 registers, but I think
        # it's broken...
        return nil if !disassembly || disassembly.empty?
        affected_registers = disassembly[1].scan(/[er][abcd]x|[er][sd]i|[er][sb]p|r\d+/)
        @affected          = @registers.select {|reg,val| affected_registers.include? reg}
      end
    end

    def inspect
      "#{classification} @ #{disassembly[0].squeeze rescue '<disassembly failed>'}"
    end

    def method_missing meth, *args
      DetailParser.send meth, @detail_string
    end
  end
end
