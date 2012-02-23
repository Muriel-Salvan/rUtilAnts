#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module URLAccess

    # Constants identifying which form is the content returned by URL handlers
    CONTENT_ERROR = 0
    CONTENT_REDIRECT = 1
    CONTENT_STRING = 2
    CONTENT_LOCALFILENAME = 3
    CONTENT_LOCALFILENAME_TEMPORARY = 4

    # Exception class handling redirection errors
    class RedirectionError < RuntimeError
    end

    module URLAccessInterface

      # Constructor
      def init_url_access
        # Get the map of plugins to read URLs
        # map< String, [ list<Regexp>, String ] >
        # map< PluginName, [ List of matching regexps, Plugin class name ] >
        @Plugins = {}
        Dir.glob(File.expand_path("#{File.dirname(__FILE__)}/URLHandlers/*.rb")).each do |iFileName|
          begin
            lPluginName = File.basename(iFileName)[0..-4]
            require "rUtilAnts/URLHandlers/#{lPluginName}"
            @Plugins[lPluginName] = [
              eval("RUtilAnts::URLCache::URLHandlers::#{lPluginName}::getMatchingRegexps"),
              "RUtilAnts::URLCache::URLHandlers::#{lPluginName}"
            ]
          rescue Exception
            log_exc$!, "Error while requiring URLHandler plugin #{iFileName}"
          end
        end
      end

      # Access the content of a URL.
      # No cache.
      # It calls a code block with the binary content of the URL (or a local file name if required).
      #
      # Parameters::
      # * *iURL* (_String_): The URL (used to detect cyclic redirections)
      # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters:
      #   * *:follow_redirections* (_Boolean_): Do we follow redirections ? [optional = true]
      #   * *:nbr_redirections_allowed* (_Integer_): Number of redirections allowed [optional = 10]
      #   * *:local_file_access* (_Boolean_): Do we need a local file to read the content from ? If not, the content itslef will be given the code block. [optional = false]
      #   * *:url_handler* (_Object_): The URL handler, if it has already been instantiated, or nil otherwise [optional = nil]
      # * _CodeBlock_: The code returning the object corresponding to the content:
      #   * *iContent* (_String_): File content, or file name if :local_file_access was true
      #   * *iFileBaseName* (_String_): The base name the file could have. Useful to get file name extensions.
      #   * Return::
      #   * _Exception_: The error encountered, or nil in case of success
      # Return::
      # * _Exception_: The error encountered, or nil in case of success
      def access_file(iURL, iParameters = {})
        rError = nil

        lFollowRedirections = iParameters[:lFollowRedirections]
        lNbrRedirectionsAllowed = iParameters[:nbr_redirections_allowed]
        lLocalFileAccess = iParameters[:local_file_access]
        lURLHandler = iParameters[:url_handler]
        if (lFollowRedirections == nil)
          lFollowRedirections = true
        end
        if (lNbrRedirectionsAllowed == nil)
          lNbrRedirectionsAllowed = 10
        end
        if (lLocalFileAccess == nil)
          lLocalFileAccess = false
        end
        if (lURLHandler == nil)
          lURLHandler = get_url_handler(iURL)
        end
        # Get the content from the handler
        lContentFormat, lContent = lURLHandler.getContent(lFollowRedirections)
        case (lContentFormat)
        when CONTENT_ERROR
          rError = lContent
        when CONTENT_REDIRECT
          # Handle too much redirections (cycles)
          if (lContent.upcase == iURL.upcase)
            rError = RedirectionError.new("Redirecting to the same URL: #{iURL}")
          elsif (lNbrRedirectionsAllowed < 0)
            rError = RedirectionError.new("Too much URL redirections for URL: #{iURL} redirecting to #{lContent}")
          elsif (lFollowRedirections)
            # Follow the redirection if we want it
            lNewParameters = iParameters.clone
            lNewParameters[:nbr_redirections_allowed] = lNbrRedirectionsAllowed - 1
            # Reset the URL handler for the new parameters.
            lNewParameters[:url_handler] = nil
            rError = access_file(lContent, lNewParameters) do |iContent, iBaseName|
              yield(iContent, iBaseName)
            end
          else
            rError = RedirectionError.new("Received invalid redirection for URL: #{iURL}")
          end
        when CONTENT_STRING
          # The content is directly accessible.
          if (lLocalFileAccess)
            # Write the content in a local temporary file
            require 'tmpdir'
            lBaseName = lURLHandler.getCorrespondingFileBaseName
            lLocalFileName = "#{Dir.tmpdir}/URLCache/#{lBaseName}"
            begin
              require 'fileutils'
              FileUtils::mkdir_p(File.dirname(lLocalFileName))
              File.open(lLocalFileName, 'wb') do |oFile|
                oFile.write(lContent)
              end
            rescue Exception
              rError = $!
              lContent = nil
            end
            if (rError == nil)
              yield(lLocalFileName, lBaseName)
              # Delete the temporary file
              File.unlink(lLocalFileName)
            end
          else
            # Give it to the code block directly
            yield(lContent, lURLHandler.getCorrespondingFileBaseName)
          end
        when CONTENT_LOCALFILENAME, CONTENT_LOCALFILENAME_TEMPORARY
          lLocalFileName = lContent
          # The content is a local file name already accessible
          if (!lLocalFileAccess)
            # First, read the local file name
            begin
              File.open(lLocalFileName, 'rb') do |iFile|
                # Replace the file name with the real content
                lContent = iFile.read
              end
            rescue Exception
              rError = $!
            end
          end
          if (rError == nil)
            yield(lContent, lURLHandler.getCorrespondingFileBaseName)
          end
          # If the file was temporary, delete it
          if (lContentFormat == CONTENT_LOCALFILENAME_TEMPORARY)
            File.unlink(lLocalFileName)
          end
        end

        return rError
      end

      # Get the URL handler corresponding to this URL
      #
      # Parameters::
      # * *iURL* (_String_): The URL
      # Return::
      # * _Object_: The URL handler
      def get_url_handler(iURL)
        rURLHandler = nil

        # Try out every regexp unless it matches.
        # If none matches, assume a local file.
        @Plugins.each do |iPluginName, iPluginInfo|
          iRegexps, iPluginClassName = iPluginInfo
          iRegexps.each do |iRegexp|
            if (iRegexp.match(iURL) != nil)
              # Found a matching handler
              rURLHandler = eval("#{iPluginClassName}.new(iURL)")
              break
            end
          end
          if (rURLHandler != nil)
            break
          end
        end
        if (rURLHandler == nil)
          # Assume a local file
          rURLHandler = eval("#{@Plugins['LocalFile'][1]}.new(iURL)")
        end

        return rURLHandler
      end

    end

    # A class giving access to the URL access functionnality
    class Manager

      include URLAccessInterface

      # Constructor
      def initialize
        init_url_access
      end

    end

    # Initialize a global plugins cache
    def self.install_url_access_on_object
      require 'rUtilAnts/SingletonProxy'
      RUtilAnts::make_singleton_proxy(RUtilAnts::URLAccess::URLAccessInterface, Object)
      init_url_access
    end

  end

end
