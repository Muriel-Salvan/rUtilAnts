#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  # Module that defines a generic way to handle plugins:
  # * No pre-load: plugins files are required when needed only
  # * Description files support: plugins files can give a description file, enumerating their dependencies, description...
  # * Support for plugins categories
  # * [If RDI is present]: Try to install dependencies before loading plugin instances
  #
  # Here are the following symbols that can be used in plugins' descriptions and are already interpreted by rUtilAnts:
  # * *Dependencies* (<em>list<RDI::Model::DependencyDescription></em>): List of dependencies this plugin depends on
  # * *PluginsDependencies* (<em>list[String,String]</em>): List of other plugins ([Category,Plugin]) this plugin depends on
  # * *Enabled* (_Boolean_): Can this plugin be loaded ?
  # Here are the symbols that are reserved bu rUtilAnts:
  # * *PluginInstance* (_Object_): The real plugin instance
  # * *PluginFileName* (_String_): The plugin's file name (or nil if none)
  # * *PluginClassName* (_String_): Name of the plugin's class to instantiate
  # * *PluginInitCode* (_Proc_): Code to call when instantiating the plugin (or nil if none)
  # * *PluginIndex* (_Integer_): Unique incremental ID identifying the plugin in its category
  # * *PluginName* (_String_): Name of the plugin
  # * *PluginCategoryName* (_String_): Name of the category of the plugin
  module Plugins

    # Exception thrown when an unknown plugin is encountered
    class UnknownPluginError < RuntimeError
    end

    # Exception thrown when an unknown category is encountered
    class UnknownCategoryError < RuntimeError
    end

    # Exception thrown when a plugin is disabled
    class DisabledPluginError < RuntimeError
    end

    # Exception thrown when a plugin can't load its dependencies
    class PluginDependenciesError < RuntimeError
    end

    # Exception thrown when a plugin fails to instantiate
    class FailedPluginError < RuntimeError
    end

    # Exception thrown when a plugin can't load its dependencies upon user request (ignore dependencies installation)
    class PluginDependenciesIgnoredError < RuntimeError
    end

    # Exception thrown when a plugin can't load its dependencies, but the user is aware of it already
    class PluginDependenciesUnresolvedError < RuntimeError
    end

    module PluginsInterface

      # Constructor
      def init_plugins
        # Map of plugins, per category
        # map< String, map< String, map< Symbol, Object > > >
        @Plugins = {}
      end

      # Register a new plugin
      #
      # Parameters::
      # * *iCategoryName* (_String_): Category this plugin belongs to
      # * *iPluginName* (_String_): Plugin name
      # * *iFileName* (_String_): File name containing the plugin (can be nil)
      # * *iDesc* (<em>map<Symbol,Object></em>): Plugin's description (can be nil)
      # * *iClassName* (_String_): Name of the plugin class
      # * *iInitCodeBlock* (_Proc_): Code block to call when initializing the real instance (can be nil)
      def register_new_plugin(iCategoryName, iPluginName, iFileName, iDesc, iClassName, iInitCodeBlock)
        # Complete the description with some metadata
        if (@Plugins[iCategoryName] == nil)
          @Plugins[iCategoryName] = {}
        end
        lDesc = nil
        if (iDesc == nil)
          lDesc = {}
        else
          lDesc = iDesc.clone
        end
        lDesc[:PluginFileName] = iFileName
        lDesc[:PluginInstance] = nil
        lDesc[:PluginClassName] = iClassName
        lDesc[:PluginInitCode] = iInitCodeBlock
        lDesc[:PluginIndex] = @Plugins[iCategoryName].size
        lDesc[:PluginName] = iPluginName
        lDesc[:PluginCategoryName] = iCategoryName
        @Plugins[iCategoryName][iPluginName] = lDesc
      end

      # Parse plugins from a given directory
      #
      # Parameters::
      # * *iCategory* (_Object_): Category those plugins will belong to
      # * *iDir* (_String_): Directory to parse for plugins
      # * *iBaseClassNames* (_String_): The base class name of plugins to be instantiated
      # * *iInitCodeBlock* (_CodeBlock_): Code to be executed first time the plugin will be instantiated (can be ommitted):
      #   * *ioPlugin* (_Object_): Plugin instance
      def parse_plugins_from_dir(iCategory, iDir, iBaseClassNames, &iInitCodeBlock)
        # Gather descriptions
        # map< String, map >
        lDescriptions = {}
        lDescFiles = Dir.glob("#{iDir}/*.desc.rb")
        lDescFiles.each do |iFileName|
          lPluginName = File.basename(iFileName)[0..-9]
          # Load the description file
          begin
            File.open(iFileName) do |iFile|
              lDesc = eval(iFile.read, nil, iFileName)
              if (lDesc.is_a?(Hash))
                lDescriptions[lPluginName] = lDesc
              else
                log_bug "Plugin description #{iFileName} is incorrect. The file should just describe a simple hash map."
              end
            end
          rescue Exception
            log_exc $!, "Error while loading file #{iFileName}. Ignoring this description."
          end
        end
        # Now, parse the plugins themselves
        if (@Plugins[iCategory] == nil)
          @Plugins[iCategory] = {}
        end
        (Dir.glob("#{iDir}/*.rb") - lDescFiles).each do |iFileName|
          lPluginName = File.basename(iFileName)[0..-4]
          # Don't load it now, but store it along with its description if it exists
          if (@Plugins[iCategory][lPluginName] == nil)
            # Check if we have a description
            lDesc = lDescriptions[lPluginName]
            register_new_plugin(
              iCategory,
              lPluginName,
              iFileName,
              lDescriptions[lPluginName],
              "#{iBaseClassNames}::#{lPluginName}",
              iInitCodeBlock
            )
          else
            log_warn "Plugin named #{lPluginName} in category #{iCategory} already exists. Please name it differently. Ignoring it from #{iFileName}."
          end
        end
      end

      # Get the named plugin instance.
      # Uses RDI if given in parameters or if Main RDI Installer defined to resolve Plugins' dependencies.
      #
      # Parameters::
      # * *iCategory* (_Object_): Category those plugins will belong to
      # * *iPluginName* (_String_): Plugin name
      # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters:
      #   * *OnlyIfExtDepsResolved* (_Boolean_): Do we return the plugin only if there is no need to install external dependencies ? [optional = false]
      #   * *RDIInstaller* (<em>RDI::Installer</em>): The RDI installer if available, or nil otherwise [optional = nil]
      #   * *RDIContextModifiers* (<em>map<String,list< [String,Object] >></em>): The map of context modifiers to be filled by the RDI installer if specified, or nil if ignored [optional = nil]
      # Return::
      # * _Object_: The corresponding plugin, or nil in case of failure
      # * _Exception_: The error, or nil in case of success
      def get_plugin_instance(iCategory, iPluginName, iParameters = {})
        rPlugin = nil
        rError = nil

        lOnlyIfExtDepsResolved = iParameters[:OnlyIfExtDepsResolved]
        if (lOnlyIfExtDepsResolved == nil)
          lOnlyIfExtDepsResolved = false
        end
        lRDIInstaller = iParameters[:RDIInstaller]
        lRDIContextModifiers = iParameters[:RDIContextModifiers]
        if (@Plugins[iCategory] == nil)
          rError = UnknownCategoryError.new("Unknown plugins category #{iCategory}.")
        else
          lDesc = @Plugins[iCategory][iPluginName]
          if (lDesc == nil)
            rError = UnknownPluginError.new("Unknown plugin #{iPluginName} in category #{iCategory}.")
          elsif (lDesc[:Enabled] == false)
            rError = DisabledPluginError.new("Plugin #{iPluginName} in category #{iCategory} is disabled.")
          else
            if (lDesc[:PluginInstance] == nil)
              lSuccess = true
              # If RDI is present, call it to get dependencies first if needed
              if (lDesc[:Dependencies] != nil)
                # If it is not given as parameter, try getting the singleton
                if ((lRDIInstaller == nil) and
                    (defined?(RDI::Installer) != nil))
                  lRDIInstaller = RDI::Installer.getMainInstance
                end
                if (lRDIInstaller != nil)
                  if (lOnlyIfExtDepsResolved)
                    # Test that each dependency is accessible
                    lSuccess = true
                    lDesc[:Dependencies].each do |iDepDesc|
                      lSuccess = lRDIInstaller.testDependency(iDepDesc)
                      if (!lSuccess)
                        # It is useless to continue
                        break
                      end
                    end
                  else
                    # Load other dependencies
                    lError, lContextModifiers, lIgnored, lUnresolved = lRDIInstaller.ensureDependencies(lDesc[:Dependencies])
                    if (lRDIContextModifiers != nil)
                      lRDIContextModifiers.merge!(lContextModifiers)
                    end
                    lSuccess = ((lError == nil) and
                                (lIgnored.empty?) and
                                (lUnresolved.empty?))
                    if (!lSuccess)
                      if (!lIgnored.empty?)
                        rError = PluginDependenciesIgnoredError.new("Unable to load plugin #{iPluginName} without its dependencies (ignored #{lIgnored.size} dependencies).")
                      elsif (!lUnresolved.empty?)
                        rError = PluginDependenciesUnresolvedError.new("Unable to load plugin #{iPluginName} without its dependencies (couldn't load #{lUnresolved.size} dependencies):\n#{lError}")
                      else
                        rError = PluginDependenciesError.new("Could not load dependencies for plugin #{iPluginName}: #{lError}")
                      end
                    end
                  end
                end
              end
              if (lSuccess)
                if (lDesc[:PluginsDependencies] != nil)
                  # Load other plugins
                  lDesc[:PluginsDependencies].each do |iPluginInfo|
                    iPluginCategory, iPluginName = iPluginInfo
                    lPlugin, lError = get_plugin_instance(iPluginCategory, iPluginName, iParameters)
                    lSuccess = (lError == nil)
                    if (!lSuccess)
                      # Don't try further
                      rError = PluginDependenciesError.new("Could not load plugins dependencies for plugin #{iPluginName}: #{lError}.")
                      break
                    end
                  end
                end
                if (lSuccess)
                  # Load the plugin
                  begin
                    # If the file name is to be required, do it now
                    if (lDesc[:PluginFileName] != nil)
                      require lDesc[:PluginFileName]
                    end
                    lPlugin = eval("#{lDesc[:PluginClassName]}.new")
                    # Add a reference to the description in the instantiated object
                    lPlugin.instance_variable_set(:@rUtilAnts_Desc, lDesc)
                    def lPlugin.pluginDescription
                      return @rUtilAnts_Desc
                    end
                    # Register this instance
                    lDesc[:PluginInstance] = lPlugin
                    # If needed, execute the init code
                    if (lDesc[:PluginInitCode] != nil)
                      lDesc[:PluginInitCode].call(lPlugin)
                    end
                  rescue Exception
                    rError = FailedPluginError.new("Error while loading file #{lDesc[:PluginFileName]} and instantiating #{lDesc[:PluginClassName]}: #{$!}. Ignoring this plugin.")
                  end
                end
              end
            end
            rPlugin = lDesc[:PluginInstance]
          end
        end

        return rPlugin, rError
      end

      # Get the named plugin description
      #
      # Parameters::
      # * *iCategory* (_Object_): Category those plugins will belong to
      # * *iPluginName* (_String_): Plugin name
      # Return::
      # * <em>map<Symbol,Object></em>: The corresponding description
      def get_plugin_description(iCategory, iPluginName)
        rDesc = nil

        if (@Plugins[iCategory] == nil)
          raise UnknownCategoryError.new("Unknown plugins category #{iCategory}.")
        else
          rDesc = @Plugins[iCategory][iPluginName]
          if (rDesc == nil)
            raise UnknownPluginError.new("Unknown plugin #{iPluginName} in category #{iCategory}.")
          end
        end

        return rDesc
      end

      # Give access to a plugin.
      # An exception is thrown if the plugin does not exist.
      #
      # Parameters::
      # * *iCategoryName* (_String_): Category of the plugin to access
      # * *iPluginName* (_String_): Name of the plugin to access
      # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters:
      #   * *OnlyIfExtDepsResolved* (_Boolean_): Do we return the plugin only if there is no need to install external dependencies ? [optional = false]
      #   * *RDIInstaller* (<em>RDI::Installer</em>): The RDI installer if available, or nil otherwise [optional = nil]
      #   * *RDIContextModifiers* (<em>map<String,list< [String,Object] >></em>): The map of context modifiers to be filled by the RDI installer if specified, or nil if ignored [optional = nil]
      # * *CodeBlock*: The code called when the plugin is found:
      #   * *ioPlugin* (_Object_): The corresponding plugin
      def access_plugin(iCategoryName, iPluginName, iParameters = {})
        lPlugin, lError = get_plugin_instance(iCategoryName, iPluginName, iParameters)
        if (lPlugin == nil)
          raise lError
        else
          yield(lPlugin)
        end
      end

      # Clear the registered plugins
      def clearPlugins
        @Plugins = {}
      end

      # Get the list of plugin names of a given category
      #
      # Parameters::
      # * *iCategoryName* (_String_): The category for which we want the plugin names list
      # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters:
      #   * *IncludeDisabled* (_Boolean_): Do we include disabled plugins ? [optional = false]
      # Return::
      # * <em>list<String></em>: The list of plugin names in this category
      def get_plugins_names(iCategoryName, iParameters = {})
        rPlugins = []

        lIncludeDisabled = iParameters[:IncludeDisabled]
        if (lIncludeDisabled == nil)
          lIncludeDisabled = false
        end
        if (@Plugins[iCategoryName] != nil)
          @Plugins[iCategoryName].each do |iPluginName, iPluginDesc|
            if ((lIncludeDisabled) or
                (iPluginDesc[:Enabled] != false))
              rPlugins << iPluginName
            end
          end
        end

        return rPlugins
      end

      # Get the map of plugins descriptions, indexed with plugin names
      #
      # Parameters::
      # * *iCategoryName* (_String_): The category for which we want the plugin names list
      # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters:
      #   * *IncludeDisabled* (_Boolean_): Do we include disabled plugins ? [optional = false]
      # Return::
      # * <em>map<String,map<Symbol,Object>></em>: The map of plugin descriptions per plugin name
      def get_plugins_descriptions(iCategoryName, iParameters = {})
        rPlugins = {}

        lIncludeDisabled = iParameters[:IncludeDisabled]
        if (lIncludeDisabled == nil)
          lIncludeDisabled = false
        end
        if (@Plugins[iCategoryName] != nil)
          if (lIncludeDisabled)
            rPlugins = @Plugins[iCategoryName]
          else
            @Plugins[iCategoryName].each do |iPluginName, iPluginDesc|
              if (iPluginDesc[:Enabled] != false)
                rPlugins[iPluginName] = iPluginDesc
              end
            end
          end
        end

        return rPlugins
      end

    end

    # Main class storing info about plugins
    class PluginsManager

      include PluginsInterface

      # Constructor
      def initialize
        init_plugins
      end

    end

    # Initialize a plugins singleton
    def self.install_plugins_on_object
      require 'rUtilAnts/SingletonProxy'
      RUtilAnts::make_singleton_proxy(RUtilAnts::Plugins::PluginsInterface, Object)
      init_plugins
    end

  end

end
