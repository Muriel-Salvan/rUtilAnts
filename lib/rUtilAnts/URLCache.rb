#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module URLCache

    # Exception for reporting server down errors.
    class ServerDownError < RuntimeError
    end

    module URLCacheInterface

      # Constructor
      def init_url_cache
        # Map of known contents, interpreted in many flavors
        # map< Integer, [ Integer, Object ] >
        # map< URL's hash, [ CRC, Content ] >
        @URLs = {}
        # Map of hosts down (no need to try again such a host)
        # map< String >
        @HostsDown = {}
      end

      # Get a content from a URL.
      # Here are the different formats the URL can have:
      # * Local file name
      # * http/https/ftp/ftps:// protocols
      # * data:image URI
      # * file:// protocol
      # It also handles redirections or zipped files
      #
      # Parameters::
      # * *iURL* (_String_): The URL
      # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters:
      #   * *:force_load* (_Boolean_): Do we force to refresh the cache ? [optional = false]
      #   * *:follow_redirections* (_Boolean_): Do we follow redirections ? [optional = true]
      #   * *:nbr_redirections_allowed* (_Integer_): Number of redirections allowed [optional = 10]
      #   * *:local_file_access* (_Boolean_): Do we need a local file to read the content from ? If not, the content itslef will be given the code block. [optional = false]
      # * _CodeBlock_: The code returning the object corresponding to the content:
      #   * *iContent* (_String_): File content, or file name if :local_file_access was true
      #   * Return::
      #   * _Object_: Object read from the content, or nil in case of error
      #   * _Exception_: The error encountered, or nil in case of success
      # Return::
      # * <em>Object</em>: The corresponding URL content, or nil in case of failure
      # * _Exception_: The error, or nil in case of success
      def get_url_content(iURL, iParameters = {})
        rObject = nil
        rError = nil

        # Parse parameters
        lForceLoad = iParameters[:force_load]
        if (lForceLoad == nil)
          lForceLoad = false
        end
        # Get the URL handler corresponding to this URL
        lURLHandler = get_url_handler(iURL)
        lServerID = lURLHandler.get_server_id
        if (@HostsDown.has_key?(lServerID))
          rError = ServerDownError.new("Server #{iURL} is currently down.")
        else
          lURLHash = iURL.hash
          # Check if it is in the cache, or if we force refresh, or if the URL was invalidated
          lCurrentCRC = lURLHandler.get_crc
          if ((@URLs[lURLHash] == nil) or
              (lForceLoad) or
              (@URLs[lURLHash][0] != lCurrentCRC))
            # Load it for real
            # Reset previous value if it was set
            @URLs[lURLHash] = nil
            # Get the object
            lObject = nil
            lAccessError = access_file(iURL, iParameters.merge(:url_handler => lURLHandler)) do |iContent, iBaseName|
              lObject, rError = yield(iContent)
            end
            if (lAccessError != nil)
              rError = lAccessError
            end
            # Put lObject in the cache if no error was found
            if (rError == nil)
              # OK, register it
              @URLs[lURLHash] = [ lCurrentCRC, lObject ]
            else
              if ((defined?(SocketError) != nil) and
                  (rError.is_a?(SocketError)))
                # We have a server down
                @HostsDown[lServerID] = nil
              end
            end
          end
          # If no error was found (errors can only happen if it was not already in the cache), take it from the cache
          if (rError == nil)
            rObject = @URLs[lURLHash][1]
          end
        end

        return rObject, rError
      end

    end

    # Class that caches every access to a URI (local file name, http, data...).
    # This ensures just that several files are instantiated just once.
    # For local files, it takes into account the file modification date/time to know if the Wx::Bitmap file has to be refreshed.
    class URLCache

      include URLCacheInterface

      # Constructor
      def initialize
        init_url_cache
      end

    end

    # Initialize a global cache
    def self.install_url_cache_on_object
      require 'rUtilAnts/SingletonProxy'
      RUtilAnts::make_singleton_proxy(RUtilAnts::URLCache::URLCacheInterface, Object)
      init_url_cache
    end

  end

end
