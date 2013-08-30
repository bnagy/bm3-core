# Abstract out Metafile drawing. Can be mixed into devices that support the
# methods #dc and #rect
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

module BM3
  module Win32
    module GDI
      module Metafile

        def play_emf_file emf_fname
          draw_emf_from_handle GDI.GetEnhMetaFile emf_fname
        end

        def play_emf_data emf_data
          p_data = make_pstr emf_data
          draw_emf_from_handle GDI.SetEnhMetaFileBits p_data.size, p_data
        end

        def draw_emf_from_handle emf_handle
          raise_win32_error if emf_handle.zero?
          GDI.PlayEnhMetaFile dc, emf_handle, rect
          GDI.DeleteEnhMetaFile emf_handle
        end

        def play_wmf_data wmf_data
          # So. WMF do not have any position or scaling information. they're just raw
          # GDI commands. They're usually stored on disk in a 'standard' nonstandard
          # way with a 'placeable metafile' header that contains that info. However,
          # the PlayMetaFile API does not allow you to pass that header, and will try
          # and draw stuff retardedly. The options, then are:
          # 1. Shell out to mspaint.exe
          # - internally that calls GDI+, converts WMF to Bitmap and displays that
          #   (which does not sound so awesome for reaching kernel stuff)
          # 2. Convert to EMF, play the EMF
          # - Easy, may lose some opportunities to be evil, not sure
          # 3. Get the scaling information from the APM header and use the Coordinate
          # Spaces and Transforms APIs to modify the target DC to correctly display
          # the WMF by applying global transforms to all the GDI drawing commands
          # contained in the WMF.
          # - This involves large amounts of pels and twips and maths and crap.
          if wmf_data[0..3] == "\xD7\xCD\xC6\x9A"
            # This is an 'Aldus Placeable Metafile', and the first 22 bytes are the
            # APM header, which needs to be stripped.
            # ref: http://msdn.microsoft.com/en-us/library/windows/desktop/ms534075(v=vs.85).aspx
            debug_info "Detected Aldus Metafile, stripping header..."
            pdata = make_pstr wmf_data[22..-1]
          else
            debug_info "Doesn't look like a WMF, playing as EMF..."
            play_emf_data( wmf_data ) and return
          end
          # Convert to EMF. MSDN says:
          # If the lpmfp parameter is NULL, the system uses the MM_ANISOTROPIC mapping
          # mode to scale the picture so that it fits the entire device surface.
          draw_emf_from_handle GDI.SetWinMetaFileBits pdata.size, pdata, dc, nil
        end
        
      end
    end
  end
end

