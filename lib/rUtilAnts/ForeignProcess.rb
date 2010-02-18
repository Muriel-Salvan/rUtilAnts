#--
# Copyright (c) 2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  # This module defines a method to run a given Ruby's object and parameters in a separate process.
  # This can be useful when $LD_LIBRARY_PATH has to be changed before continuing.
  module ForeignProcess

    # Class containing info for serialized method calls
    class MethodCallInfo

      # Log file
      #   String
      attr_accessor :LogFile

      # Lib root dir
      #   String
      attr_accessor :LibRootDir

      # Bug tracker URL
      #   String
      attr_accessor :BugTrackerURL

      # Load path
      #   list<String>
      attr_accessor :LoadPath

      # List of files to require
      #   list<String>
      attr_accessor :RequireFiles

      # Serialized MethodDetails
      # It is stored serialized as to unserialize it we first need to unserialize the RequireFiles
      #   String
      attr_accessor :SerializedMethodDetails

      class MethodDetails

        # Object to call the function on
        #   Object
        attr_accessor :Object

        # Method to call
        #   Symbol
        attr_accessor :Method

        # Parameters
        #   list<Object>
        attr_accessor :Parameters

      end

    end

    # Execute a command in another Ruby session, executing some Shell commands before invocation.
    #
    # Parameters:
    # * *iShellCmd* (_String_): Shell command to invoke before Ruby
    # * *iObject* (_Object_): Object that will have a function to call in the new session
    # * *iMethod* (_Symbol_): Method to call on the object
    # * *Parameters* (<em>list<Object></em>): Remaining parameters
    # Return:
    # * _Exception_: An error, or nil if success
    # * _Object_: The result of the function call (valid only if no error returned)
    def self.execCmdOtherSession(iShellCmd, iObject, iMethod, iParameters)
      rError = nil
      rResult = nil

      logDebug "Execute method #{iMethod}(#{iParameters.join(', ')}) in a new process with shell command: #{iShellCmd} ..."

      # Create an object that we will serialize, containing all needed information for the session
      lInfo = MethodCallInfo.new
      lInfo.LogFile = getLogFile
      lInfo.LibRootDir = getLibRootDir
      lInfo.BugTrackerURL = getBugTrackerURL
      lInfo.RequireFiles = $".clone
      lInfo.LoadPath = $LOAD_PATH.clone
      lMethodDetails = MethodCallInfo::MethodDetails.new
      lMethodDetails.Parameters = iParameters
      lMethodDetails.Method = iMethod
      lMethodDetails.Object = iObject
      logDebug "Method to be marshalled: #{lMethodDetails.inspect}"
      lInfo.SerializedMethodDetails = Marshal.dump(lMethodDetails)
      # Dump this object in a temporary file
      require 'tmpdir'
      lInfoFileName = "#{Dir.tmpdir}/RubyExec_#{Thread.object_id}_Info"
      File.open(lInfoFileName, 'w') do |oFile|
        oFile.write(Marshal.dump(lInfo))
      end
      # For security reasons, ensure that only us can read this file. It can contain passwords.
      require 'fileutils'
      FileUtils.chmod(0700, lInfoFileName)
      # Generate the Ruby file that will run everything
      lExecFileName = "#{Dir.tmpdir}/RubyExec_#{Thread.object_id}_Exec.rb"
      File.open(lExecFileName, 'w') do |oFile|
        oFile << "
\# This is a generated file that should not stay persistent. You can delete it.
\# It has been generated by rUtilAnts::ForeignProcess module. Check http://rutilants.sourceforge.net for further details.
require '#{File.expand_path(__FILE__)}'
RUtilAnts::ForeignProcess::executeEmbeddedFunction(ARGV[0], ARGV[1])
"
      end
      # For security reasons, ensure that only us can read and execute this file.
      FileUtils.chmod(0700, lExecFileName)
      # Name the file that will receive the result of the function call
      lResultFileName = "#{Dir.tmpdir}/RubyExec_#{Thread.object_id}_Result"

      # Call this Ruby file by first executing the Shell command
      lCmd = "#{iShellCmd}; ruby -w #{lExecFileName} #{lInfoFileName} #{lResultFileName} 2>&1"
      lOutput = `#{lCmd}`
      lErrorCode = $?
      if (lErrorCode == 0)
        # Read the result file
        File.open(lResultFileName, 'r') do |iFile|
          rResult = Marshal.load(iFile.read)
        end
      else
        rError = RuntimeError.new("Error while running command \"#{lCmd}\". Here is the output:\n#{lOutput}.")
      end
      
      # Remove files
      File.unlink(lInfoFileName)
      File.unlink(lExecFileName)
      if (File.exists?(lResultFileName))
        File.unlink(lResultFileName)
      end

      logDebug "Method executed with error #{rError} and result #{rResult}."

      return rError, rResult
    end

    # Execute a function along with its parameters stored in a file.
    # This method is used by the file generated by execCmdOtherSession.
    # It should not be called directly.
    #
    # Parameters:
    # * *iInfoFileName* (_String_): The file containing info
    # * *iResultFileName* (_String_): The file used to store the result serialized
    def self.executeEmbeddedFunction(iInfoFileName, iResultFileName)
      begin
        # Read the file
        lInfo = nil
        File.open(iInfoFileName, 'r') do |iFile|
          lInfo = Marshal.load(iFile.read)
        end
        # Set the load path
        lInfo.LoadPath.each do |iDir|
          if (!$LOAD_PATH.include?(iDir))
            $LOAD_PATH << iDir
          end
        end
        # Require all given files
        lInfo.RequireFiles.each do |iRequireName|
          require iRequireName
        end
        # Initialize logging
        RUtilAnts::Logging::initializeLogging(lInfo.LibRootDir, lInfo.BugTrackerURL)
        setLogFile(lInfo.LogFile)
        logDebug "New process spawned with requires: #{lInfo.RequireFiles.join(', ')}."
        # Unserialize the method details
        lMethodDetails = Marshal.load(lInfo.SerializedMethodDetails)
        # Call the method on the object with all its parameters
        logDebug "Calling method #{lMethodDetails.Method}(#{lMethodDetails.Parameters.join(', ')}) ..."
        lResult = lMethodDetails.Object.send(lMethodDetails.Method, *lMethodDetails.Parameters)
        logDebug "Method returned #{lResult}."
      rescue Exception
        lResult = RuntimeError.new("Error occurred while executing foreign call: #{$!}. Backtrace: #{$!.join("\n")}")
      end
      begin
        # Store the result in the file for return
        File.open(iResultFileName, 'w') do |oFile|
          oFile.write(Marshal.dump(lResult))
        end
        # For security reasons, ensure that only us can read this file. It can contain passwords.
        require 'fileutils'
        FileUtils.chmod(0700, iResultFileName)
      rescue Exception
        logErr "Error while writing result in to #{iResultFileName}: #{$!}."
      end
    end

    # Initialize the ForeignProcess methods in the Object namespace
    def self.initializeForeignProcess
      Object.module_eval('include RUtilAnts::ForeignProcess')
    end

  end

end
