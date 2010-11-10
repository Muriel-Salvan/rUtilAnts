#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module Platform

    class PlatformInfo

      # Return the ID of the OS
      # Applications may adapt their behavior based on it.
      #
      # Return:
      # * _Integer_: OS ID
      def os
        return OS_CYGWIN
      end

      # Return the list of directories where we look for executables
      #
      # Return:
      # * <em>list<String></em>: List of directories
      def getSystemExePath
        return ENV['PATH'].split(':')
      end

      # Set the list of directories where we look for executables
      #
      # Parameters:
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def setSystemExePath(iNewDirsList)
        ENV['PATH'] = iNewDirsList.join(':')
      end

      # Return the list of file extensions that might be discretely happened to executable files.
      # This is the optional extensions that can be happened when invoked from a terminal.
      #
      # Return:
      # * <em>list<String></em>: List of extensions (including .)
      def getDiscreteExeExtensions
        return []
      end

      # Return the list of directories where we look for libraries
      #
      # Return:
      # * <em>list<String></em>: List of directories
      def getSystemLibsPath
        rList = ENV['PATH'].split(':')

        if (ENV['LD_LIBRARY_PATH'] != nil)
          rList += ENV['LD_LIBRARY_PATH'].split(':')
        end

        return rList
      end

      # Set the list of directories where we look for libraries
      #
      # Parameters:
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def setSystemLibsPath(iNewDirsList)
        ENV['LD_LIBRARY_PATH'] = iNewDirsList.join(':')
      end

      # This method sends a message (platform dependent) to the user, without the use of wxruby
      #
      # Parameters:
      # * *iMsg* (_String_): The message to display
      def sendMsg(iMsg)
        # TODO: Handle case of xmessage not installed
        # Create a temporary file with the content to display
        require 'tmpdir'
        lTmpFileName = "#{Dir.tmpdir}/RUA_MSG"
        File.open(lTmpFileName, 'w') do |oFile|
          oFile.write(iMsg)
        end
        system("xmessage -file #{lTmpFileName}")
        File.unlink(lTmpFileName)
      end

      # Execute a Shell command.
      # Do not wait for its termination.
      #
      # Parameters:
      # * *iCmd* (_String_): The command to execute
      # * *iInTerminal* (_Boolean_): Do we execute this command in a separate terminal ?
      # Return:
      # * _Exception_: Error, or nil if success
      def execShellCmdNoWait(iCmd, iInTerminal)
        rException = nil

        if (iInTerminal)
          # TODO: Handle case of xterm not installed
          if (!system("xterm -e \"#{iCmd}\""))
            rException = RuntimeError.new
          end
        else
          begin
            IO.popen(iCmd)
          rescue Exception
            rException = $!
          end
        end

        return rException
      end

      # Execute a given URL to be launched in a browser
      #
      # Parameters:
      # * *iURL* (_String_): The URL to launch
      # Return:
      # * _String_: Error message, or nil if success
      def launchURL(iURL)
        rError = nil

        begin
          IO.popen("xdg-open '#{iURL}'")
        rescue Exception
          rError = $!.to_s
        end

        return rError
      end

      # Get file extensions specifics to executable files
      #
      # Return:
      # * <em>list<String></em>: List of extensions (including . character). It can be empty.
      def getExecutableExtensions
        return []
      end

      # Get prohibited characters from file names
      #
      # Return:
      # * _String_: String of prohibited characters in file names
      def getProhibitedFileNamesCharacters
        return '/'
      end

    end

  end

end
