#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module Platform

    module PlatformInfo

      # Return the ID of the OS
      # Applications may adapt their behavior based on it.
      #
      # Return::
      # * _Integer_: OS ID
      def os
        return OS_LINUX
      end

      # Return the list of directories where we look for executables
      #
      # Return::
      # * <em>list<String></em>: List of directories
      def getSystemExePath
        return ENV['PATH'].split(':')
      end

      # Set the list of directories where we look for executables
      #
      # Parameters::
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def setSystemExePath(iNewDirsList)
        ENV['PATH'] = iNewDirsList.join(':')
      end

      # Return the list of file extensions that might be discretely happened to executable files.
      # This is the optional extensions that can be happened when invoked from a terminal.
      #
      # Return::
      # * <em>list<String></em>: List of extensions (including .)
      def getDiscreteExeExtensions
        return []
      end

      # Return the list of directories where we look for libraries
      #
      # Return::
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
      # Parameters::
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def setSystemLibsPath(iNewDirsList)
        ENV['LD_LIBRARY_PATH'] = iNewDirsList.join(':')
      end

      # This method sends a message (platform dependent) to the user, without the use of wxruby
      #
      # Parameters::
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
      # Parameters::
      # * *iCmd* (_String_): The command to execute
      # * *iInTerminal* (_Boolean_): Do we execute this command in a separate terminal ?
      # Return::
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
      # Parameters::
      # * *iURL* (_String_): The URL to launch
      # Return::
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
      # Return::
      # * <em>list<String></em>: List of extensions (including . character). It can be empty.
      def getExecutableExtensions
        return []
      end

      # Get prohibited characters from file names
      #
      # Return::
      # * _String_: String of prohibited characters in file names
      def getProhibitedFileNamesCharacters
        return '/'
      end

      # Create a shortcut (ln -s on Cygwin/Unix systems, a .lnk file on Windows systems)
      #
      # Parameters::
      # * *iSrc* (_String_): The source file
      # * *iDst* (_String_): The destination file
      def createShortcut(iSrc, iDst)
        require 'fileutils'
        FileUtils::ln_s(iSrc, iDst)
      end

      # Get the name of a real file name, pointed by a shortcut.
      # On Windows systems, it will be the target of the lnk file.
      #
      # Parameters::
      # * *iShortcutName* (_String_): Name of the shortcut (same name used by createShortcut). Don't use OS specific extensions in this name (no .lnk).
      # Return::
      # * _String_: The real file name pointed by this shortcut
      def followShortcut(iShortcutName)
        return File.readlink(iShortcutName)
      end

      # Get the real file name of a shortcut
      #
      # Parameters::
      # * *iDst* (_String_): The destination file that will host the shortcut
      # Return::
      # * _String_: The real shortcut file name
      def getShortcutFileName(iDst)
        return iDst
      end

    end

  end

end
