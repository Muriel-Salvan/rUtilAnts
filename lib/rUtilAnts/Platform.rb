#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module Platform

    module PlatformInterface

      # Initialize the module
      def self.includePlatformSpecificModule
        # Get the OS
        require 'rbconfig'
        real_os ||= (
          host_os = RbConfig::CONFIG['host_os']
          case host_os
          when /cygwin/
            'cygwin'
          when /mswin|msys|mingw|bccwin|wince|emc/
            'windows'
          when /darwin|mac os/
            'macosx'
          when /linux/
            'linux'
          when /solaris|bsd/
            'unix'
          else
            raise RuntimeError, "Unknown os: #{host_os.inspect}"
          end
        )
        # Require the platform info
        begin
          require "rUtilAnts/Platforms/#{real_os}/PlatformInfo"
        rescue Exception
          if (!defined?(log_bug))
            require 'rUtilAnts/Logging'
            RUtilAnts::Logging::install_logger_on_object
          end
          log_bug "Current platform #{real_os} is not supported (#{$!})."
          raise RuntimeError, "Current platform #{real_os} is not supported (#{$!})."
        end
        # Include the platform specific module
        PlatformInterface.module_eval('include RUtilAnts::Platform::PlatformInfo')
      end

      includePlatformSpecificModule

    end

    class Manager

      include PlatformInterface

    end

    # OS constants
    OS_WINDOWS = 0
    OS_LINUX = 1
    OS_CYGWIN = 2
    OS_MACOSX = 3

    # Initialize the platform info
    def self.install_platform_on_object
      require 'rUtilAnts/SingletonProxy'
      RUtilAnts::make_singleton_proxy(RUtilAnts::Platform::PlatformInterface, Object)
    end

  end

end
