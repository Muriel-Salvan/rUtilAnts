#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module Misc

    # Set these methods into the Object namespace
    def self.initializeMisc
      Object.module_eval('include RUtilAnts::Misc')
    end

    # Get a valid file name, taking into account platform specifically prohibited characters in file names.
    #
    # Parameters:
    # * *iFileName* (_String_): The original file name wanted
    # Return:
    # * _String_: The correct file name
    def getValidFileName(iFileName)
      if ((defined?($rUtilAnts_Platform_Info) != nil))
        return iFileName.gsub(/[#{Regexp.escape($rUtilAnts_Platform_Info.getProhibitedFileNamesCharacters)}]/, '_')
      else
        return iFileName
      end
    end

    # Extract a Zip archive in a given system dependent lib sub-directory
    #
    # Parameters:
    # * *iZipFileName* (_String_): The zip file name to extract content from
    # * *iDirName* (_String_): The name of the directory to store the zip to
    # Return:
    # * _Exception_: Error, or nil in case of success
    def extractZipFile(iZipFileName, iDirName)
      rError = nil

      # Use RDI if possible to ensure the dependencies on zlib.dll and rubyzip
      if (defined?(RDI) != nil)
        lRDIInstaller = RDI::Installer.getMainInstance
        if (lRDIInstaller != nil)
          # First, test that the DLL exists.
          # If it does not exist, we can't install it, because ZLib.dll is downloadable only in ZIP format (kind of stupid ;-) )
          lDLLDep = nil
          case $rUtilAnts_Platform_Info.os
          when OS_WINDOWS
            lDLLDep = RDI::Model::DependencyDescription.new('ZLib DLL').addDescription( {
              :Testers => [
                {
                  :Type => 'DynamicLibraries',
                  :Content => [ 'zlib.dll' ]
                }
              ],
              # We can't install this one
              :Installers => []
            } )
          else
            logBug "Sorry, installing ZLib on your platform #{$rUtilAnts_Platform_Info.os} is not yet supported."
          end
          if ((lDLLDep != nil) and
              (!lRDIInstaller.testDependency(lDLLDep)))
            # Try adding the default local location for libraries
            lRDIInstaller.ensureLocationInContext('LibraryPath', lRDIInstaller.getDefaultInstallLocation('Download', RDI::DEST_LOCAL))
            # Try again
            if (!lRDIInstaller.testDependency(lDLLDep))
              logErr "zlib.dll is not installed in your system.\nUnfortunately RDI can't help because the only way to install it is to download it through a ZIP file.\nPlease install it manually from http://zlib.net (you can do it now and click OK once it is installed)."
            end
          end
          # Then, ensure the gem dependency
          rError, lCMApplied, lIgnored, lUnresolved = lRDIInstaller.ensureDependencies(
            [
              RDI::Model::DependencyDescription.new('RubyZip').addDescription( {
                :Testers => [
                  {
                    :Type => 'RubyRequires',
                    :Content => [ 'zip/zipfilesystem' ]
                  }
                ],
                :Installers => [
                  {
                    :Type => 'Gem',
                    :Content => 'rubyzip',
                    :ContextModifiers => [
                      {
                        :Type => 'GemPath',
                        :Content => '%INSTALLDIR%'
                      }
                    ]
                  }
                ]
              } )
            ]
          )
          if (!lIgnored.empty?)
            rError = RuntimeError.new("Unable to install RubyZip without its dependencies (#{lIgnored.size} ignored dependencies).")
          elsif (!lUnresolved.empty?)
            rError = RuntimeError.new("Unable to install RubyZip without its dependencies (#{lUnresolved.size} unresolved dependencies):\n#{rError}")
          end
        end
      end
      if (rError == nil)
        # Extract content of iFileName to iDirName
        begin
          # We don't put this require in the global scope as it needs first a DLL to be loaded by plugins
          require 'zip/zipfilesystem'
          Zip::ZipInputStream::open(iZipFileName) do |iZipFile|
            while (lEntry = iZipFile.get_next_entry)
              lDestFileName = "#{iDirName}/#{lEntry.name}"
              if (lEntry.directory?)
                FileUtils::mkdir_p(lDestFileName)
              else
                FileUtils::mkdir_p(File.dirname(lDestFileName))
                # If the file already exist, first delete it to replace it with ours
                if (File.exists?(lDestFileName))
                  File.unlink(lDestFileName)
                end
                lEntry.extract(lDestFileName)
              end
            end
          end
        rescue Exception
          rError = $!
        end
      end

      return rError
    end

    # Execute a code block after having changed current directory.
    # Ensure the directory will be changed back at the end of the block, even if exceptions are thrown.
    #
    # Parameters:
    # * *iDir* (_String_): The directory to change into
    # * *CodeBlock*: Code called once the current directory has been changed
    def changeDir(iDir)
      lOldDir = Dir.getwd
      Dir.chdir(iDir)
      begin
        yield
      rescue Exception
        Dir.chdir(lOldDir)
        raise
      end
      Dir.chdir(lOldDir)
    end

    # Constants used for fileMutex
    # There was no lock on the mutex
    FILEMUTEX_NO_LOCK = 0
    # There was a lock on the mutex, but former process did not exist anymore
    FILEMUTEX_ZOMBIE_LOCK = 1
    # The lock is taken by a running process
    FILEMUTEX_LOCK_TAKEN = 2
    # The lock file is invalid
    FILEMUTEX_INVALID_LOCK = 3
    # Execute a code block protected by a file mutex
    #
    # Parameters:
    # * *iProcessID* (_String_): Process ID to be used to identify the mutex
    # * *CodeBlock*: The code called if the mutex is taken
    # Return:
    # * _Integer_: Error code
    def fileMutex(iProcessID)
      rResult = FILEMUTEX_NO_LOCK

      # Prevent concurrent execution
      require 'tmpdir'
      lLockFile = "#{Dir.tmpdir}/FileMutex_#{iProcessID}.lock"
      if (File.exists?(lLockFile))
        logErr "Another instance of process #{iProcessID} is already running. Delete file #{lLockFile} if it is not."
        begin
          lDetails = nil
          File.open(lLockFile, 'r') do |iFile|
            lDetails = eval(iFile.read)
          end
          logErr "Details of the running instance: #{lDetails.inspect}"
          # If the process does not exist anymore, remove the lock file
          # TODO: Adapt this to non Unix systems
          if (File.exists?("/proc/#{lDetails[:PID]}"))
            rResult = FILEMUTEX_LOCK_TAKEN
          else
            logErr "Process #{lDetails[:PID]} does not exist anymore. Removing lock file."
            File.unlink(lLockFile)
            rResult = FILEMUTEX_ZOMBIE_LOCK
          end
        rescue Exception
          logErr "Invalid lock file #{lLockFile}: #{$!}."
          rResult = FILEMUTEX_INVALID_LOCK
        end
      end
      if ((rResult == FILEMUTEX_NO_LOCK) or
          (rResult == FILEMUTEX_ZOMBIE_LOCK))
        # Create the lock for our process
        File.open(lLockFile, 'w') do |oFile|
          oFile << "
            {
              :ExecutionTime => '#{DateTime.now.strftime('%Y-%m-%d %H:%M:%S')}',
              :PID => '#{Process.pid}'
            }
          "
        end
        begin
          yield
          File.unlink(lLockFile)
        rescue Exception
          begin
            File.unlink(lLockFile)
          rescue Exception
            logErr "Exception while deleting lock file #{lLockFile}: #{$!}"
          end
          raise
        end
      end
    end

  end

end