#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'ezcrypto'
require 'zlib'
require 'fileutils'

module RUtilAnts

  module Archive

    # Class used to give the encoders a streaming interface
    class StringWriter

      # Buffer size used in bytes
      BUFFER_SIZE = 8388608

      # Constructor
      #
      # Parameters:
      # * *iPassword* (_String_): Password encrypting data
      # * *iSalt* (_String_): Salt encoding data
      # * *oFile* (_IO_): The IO that will receive encrypted data
      def initialize(iPassword, iSalt, oFile)
        @Password, @Salt, @File = iPassword, iSalt, oFile
        @Buffer = ''
      end

      # Add a string to write
      #
      # Parameters:
      # * *iData* (_String_): The data to encrypt and write
      def <<(iData)
        # Add to the buffer
        if (@Buffer.size + iData.size < BUFFER_SIZE)
          @Buffer.concat(iData)
        else
          # Flush the completed buffer
          lIdxData = BUFFER_SIZE-@Buffer.size
          @Buffer.concat(iData[0..lIdxData-1])
          flush
          # And now flush new data buffers
          @Buffer = iData[lIdxData..lIdxData+BUFFER_SIZE-1]
          while (@Buffer.size == BUFFER_SIZE)
            flush
            lIdxData += BUFFER_SIZE
            @Buffer = iData[lIdxData..lIdxData+BUFFER_SIZE-1]
          end
        end
      end

      # Flush current data in the file
      def flush
        if (!@Buffer.empty?)
          # Compress
          lZippedData = Zlib::Deflate.new.deflate(@Buffer, Zlib::FINISH)
          # Encrypt
          lEncryptedData = EzCrypto::Key.encrypt_with_password(@Password, @Salt, lZippedData)
          # Write
          @File.write([lEncryptedData.size].pack('l'))
          @File.write(lEncryptedData)
          @Buffer = ''
        end
      end

    end

    # Class used to give the decoders a streaming interface
    class StringReader

      # Constructor
      #
      # Parameters:
      # * *iPassword* (_String_): Password encrypting data
      # * *iSalt* (_String_): Salt encoding data
      # * *iFile* (_IO_): The IO that will send encrypted data
      def initialize(iPassword, iSalt, iFile)
        @Password, @Salt, @File = iPassword, iSalt, iFile
      end

      # Get the next string encrypted
      #
      # Return:
      # * _String_: The next string encrypted (or nil if none)
      def get
        rObject = nil

        # Read
        lStrChunkSize = @File.read(4)
        if (lStrChunkSize != nil)
          lChunkSize = lStrChunkSize.unpack('l')[0]
          lData = @File.read(lChunkSize)
          # Decrypt
          lDecryptedData = EzCrypto::Key.decrypt_with_password(@Password, @Salt, lData)
          # Uncompress
          rObject = Zlib::Inflate.new.inflate(lDecryptedData)
        end

        return rObject
      end

    end

    TYPE_OBJECT = 'O'
    TYPE_STRING = 'S'

    # Class used to write a Ruby object
    class ObjectWriter

      # Constructor
      #
      # Parameters:
      # * *iPassword* (_String_): Password encrypting data
      # * *iSalt* (_String_): Salt encoding data
      # * *oFile* (_IO_): The IO that will receive encrypted data
      def initialize(iPassword, iSalt, oFile)
        @StringWriter = StringWriter.new(iPassword, iSalt, oFile)
      end

      # Add an object to write
      #
      # Parameters:
      # * *iObject* (_Object_): The object to write
      def <<(iObject)
        lStrType = nil
        lStrObject = nil
        if (iObject.is_a?(String))
          lStrType = TYPE_STRING
          lStrObject = iObject
        else
          lStrType = TYPE_OBJECT
          lStrObject = Marshal.dump(iObject)
        end
        # Write it along with its length
        @StringWriter << (lStrType + [lStrObject.size].pack('l') + lStrObject)
      end

      # Flush
      def flush
        @StringWriter.flush
      end

    end

    # Class used to read a Ruby object
    class ObjectReader

      # Size of the object header
      OBJECT_HEADER_SIZE = 5

      # Constructor
      #
      # Parameters:
      # * *iPassword* (_String_): Password encrypting data
      # * *iSalt* (_String_): Salt encoding data
      # * *iFile* (_IO_): The IO that will send encrypted data
      def initialize(iPassword, iSalt, iFile)
        @StringReader = StringReader.new(iPassword, iSalt, iFile)
        @BufferRead = ''
      end

      # Get the next object encrypted
      #
      # Return:
      # * _Object_: The next object encrypted (or nil if none)
      def get
        rObject = nil

        # Read the size first
        while (@BufferRead.size < OBJECT_HEADER_SIZE)
          @BufferRead.concat(@StringReader.get)
        end
        lObjectType = @BufferRead[0..0]
        lObjectSize = @BufferRead[1..OBJECT_HEADER_SIZE-1].unpack('l')[0]
        # Then read the data
        while (@BufferRead.size < OBJECT_HEADER_SIZE+lObjectSize)
          @BufferRead.concat(@StringReader.get)
        end
        case lObjectType
        when TYPE_OBJECT
          rObject = Marshal.load(@BufferRead[OBJECT_HEADER_SIZE..OBJECT_HEADER_SIZE+lObjectSize-1])
        when TYPE_STRING
          rObject = @BufferRead[OBJECT_HEADER_SIZE..OBJECT_HEADER_SIZE+lObjectSize-1]
        else
          raise RuntimeError.new("Unknown object type: #{lObjectType}")
        end
        @BufferRead = @BufferRead[OBJECT_HEADER_SIZE+lObjectSize..-1]

        return rObject
      end

    end

    # Class used to write files and directories
    class FilesWriter

      # Size of the buffer used to write files contents
      FILE_BUFFER_SIZE = 8388608

      # Constructor
      #
      # Parameters:
      # * *iPassword* (_String_): Password encrypting data
      # * *iSalt* (_String_): Salt encoding data
      # * *oFile* (_IO_): The IO that will receive encrypted data
      def initialize(iPassword, iSalt, oFile)
        @ObjectWriter = ObjectWriter.new(iPassword, iSalt, oFile)
        # The list of empty directories
        # list< String >
        @EmptyDirs = []
        # The list of files, along with their size
        # list< [ String, Integer ] >
        @LstFiles = []
        # The total size of bytes
        # Integer
        @TotalSize = 0
      end

      # Add a single file to write
      #
      # Parameters:
      # * *iFileName* (_String_): File to add
      def addFile(iFileName)
        lFileSize = File.size(iFileName)
        @LstFiles << [ iFileName, lFileSize ]
        @TotalSize += lFileSize
      end

      # Add a directory with all its recursive content
      #
      # Parameters:
      # * *iDirName* (_String_): Name of the directory
      def addDir(iDirName)
        lEmpty = true
        lRealDir = iDirName
        if (iDirName == '')
          lRealDir = '.'
        end
        Dir.foreach(lRealDir) do |iFileName|
          if ((iFileName != '.') and
              (iFileName != '..'))
            lEmpty = false
            lCompleteFileName = "#{iDirName}/#{iFileName}"
            if (iDirName == '')
              lCompleteFileName = iFileName
            end
            if (File.directory?(lCompleteFileName))
              addDir(lCompleteFileName)
            else
              addFile(lCompleteFileName)
            end
          end
        end
        if (lEmpty)
          @EmptyDirs << iDirName
        end
      end

      # Add a files filter
      #
      # Parameters:
      # * *iFilesFilter* (_String_): The files filter, to be used with glob
      def addFiles(iFilesFilter)
        Dir.glob(iFilesFilter).each do |iFileName|
          if (!File.directory?(iFileName))
            addFile(iFileName)
          end
        end
      end

      # Dump files to write on screen
      def dump
        logMsg "#{@EmptyDirs.size} empty directories:"
        @EmptyDirs.each_with_index do |iDirName, iIdxDir|
          logMsg "* [#{iIdxDir}]: #{iDirName}"
        end
        logMsg "#{@LstFiles.size} files (#{@TotalSize} bytes):"
        @LstFiles.each_with_index do |iFileInfo, iIdxFile|
          iFileName, iFileSize = iFileInfo
          logMsg "* [#{iIdxFile}]: #{iFileName} (#{iFileSize} bytes)"
        end
      end

      # Write everything in the file
      def write
        # First, the list of empty directories and the header
        @ObjectWriter << [ @EmptyDirs, @LstFiles.size, @TotalSize ]
        # Then each file
        lEncodedSize = 0
        @LstFiles.each do |iFileInfo|
          iFileName, iFileSize = iFileInfo
          lNbrChunks = iFileSize/FILE_BUFFER_SIZE
          if (iFileSize % FILE_BUFFER_SIZE != 0)
            lNbrChunks += 1
          end
          logDebug "Writing file #{iFileName} (#{iFileSize} bytes, #{lNbrChunks} chunks) ..."
          @ObjectWriter << [ iFileName, lNbrChunks ]
          File.open(iFileName, 'rb') do |iFile|
            lNbrChunks.times do |iIdxChunk|
              lFileDataChunk = iFile.read(FILE_BUFFER_SIZE)
              @ObjectWriter << lFileDataChunk
              lEncodedSize += lFileDataChunk.size
              $stdout.write("#{(lEncodedSize*100)/@TotalSize} %\015")
            end
          end
        end
        @ObjectWriter.flush
      end

    end

    # Class used to read files and directories
    class FilesReader

      # Constructor
      #
      # Parameters:
      # * *iPassword* (_String_): Password encrypting data
      # * *iSalt* (_String_): Salt encoding data
      # * *iFile* (_IO_): The IO that will send encrypted data
      def initialize(iPassword, iSalt, iFile)
        @ObjectReader = ObjectReader.new(iPassword, iSalt, iFile)
      end

      # Read the files and write them in the current directory
      def read
        # First, read the archive header
        lEmptyDirs, lNbrFiles, lTotalSize = @ObjectReader.get
        # Create the empty directories
        lEmptyDirs.each do |iDirName|
          FileUtils::mkdir_p(iDirName)
        end
        # Read each file
        lDecodedSize = 0
        lNbrFiles.times do |iIdxFile|
          lFileName, lNbrChunks = @ObjectReader.get
          logDebug "Reading file #{lFileName} (#{lNbrChunks} chunks) ..."
          FileUtils::mkdir_p(File.dirname(lFileName))
          File.open(lFileName, 'wb') do |oFile|
            lNbrChunks.times do |iIdxChunk|
              lFileDataChunk = @ObjectReader.get
              oFile.write(lFileDataChunk)
              lDecodedSize += lFileDataChunk.size
              $stdout.write("#{(lDecodedSize*100)/lTotalSize} %\015")
            end
          end
        end
      end

    end

  end

end
