#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
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

  end

end