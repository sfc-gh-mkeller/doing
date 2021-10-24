# frozen_string_literal: true

module Doing
  # Plugin handling
  module Plugins
    class << self

      def user_home
        @user_home ||= if Dir.respond_to?('home')
                         Dir.home
                       else
                         File.expand_path('~')
                       end
      end

      def plugins
        @plugins ||=  {
                        import: {},
                        export: {}
                      }
      end

      ##
      # Load plugins from plugins folder
      #
      def load_plugins(add_dir = nil)
        add_dir ||= '~/.config/doing/plugins'
        plugins_path(add_dir).each do |plugin_search_path|
          Dir.glob(File.join(plugin_search_path, '**', '*.rb')).sort.each do |plugin|
            require plugin
          end
        end

        plugins
      end

      # Public: Setup the plugin search path
      #
      # Returns an Array of plugin search paths
      def plugins_path(add_dir = nil)
        paths = Array(File.join(File.dirname(__FILE__), 'plugins'))
        paths << File.join(add_dir) if add_dir
        paths.map { |d| File.expand_path(d) }
      end

      ##
      # Register a plugin
      #
      # param: +[String|Array]+ title  The name of the plugin (can be an array of names)
      #
      # param: +type+ The plugin type (:import, :export)
      #
      # param: +klass+ The class responding to :render or :import
      #
      #
      # returns: Success boolean
      #
      def register(title, type, klass)
        validate_plugin(type, klass)

        if title.is_a?(Array)
          title.each { |t| register(t, type, klass) }
          return
        end

        settings = if klass.respond_to? :settings
                     klass.settings
                   else
                     { trigger: title.normalize_trigger, config: {} }
                   end

        plugins[type] ||= {}
        plugins[type][title] = {
          trigger: settings[:trigger].normalize_trigger || title.normalize_trigger,
          class: klass,
          templates: settings[:templates] || nil,
          config: settings[:config] || {}
        }
      end

      def validate_plugin(type, klass)
        type = valid_type(type)
        case type
        when :import
          raise Errors::PluginUncallable, 'Import plugins must respond to :import' unless klass.respond_to? :import

          false
        when :export
          raise Errors::PluginUncallable, 'Export plugins must respond to :render' unless klass.respond_to? :render

          false
        else
          true
        end
      end

      ##
      ## @brief      Return array of available plugin names
      ##
      ## @param      type  Plugin type (:import, :export)
      ##
      ## @returns    [Array<String>] plugin names
      ##
      def available_plugins(type: :export)
        type = valid_type(type)
        plugins[type].keys.sort
      end

      ##
      ## @brief      Return string version of plugin names
      ##
      ## @param      type       Plugin type (:import, :export)
      ## @param      separator  The separator to join names with
      ##
      ## @return     [String]   Plugin names
      ##
      def plugin_names(type: :export, separator: '|')
        type = valid_type(type)
        available_plugins(type: type).join(separator)
      end

      ##
      ## @brief      Return a regular expression of all
      ##             plugin triggers for type
      ##
      ## @param      type  The type :import or :export
      ##
      def plugin_regex(type: :export)
        type = valid_type(type)
        pattern = []
        plugins[type].each do |_, options|
          pattern << options[:trigger].normalize_trigger
        end
        Regexp.new("^(?:#{pattern.join('|')})$", true)
      end

      def plugin_templates(type: :export)
        type = valid_type(type)
        templates = []
        plugs = plugins[type].clone
        plugs.delete_if { |t, o| o[:templates].nil? }.each do |_, options|
          options[:templates].each do |t|
            templates << t[:name]
          end
        end

        templates
      end

      def template_regex(type: :export)
        type = valid_type(type)
        pattern = []
        plugs = plugins[type].clone
        plugs.delete_if { |t, o| o[:templates].nil? }.each do |_, options|
          options[:templates].each do |t|
            pattern << t[:trigger].normalize_trigger
          end
        end
        Regexp.new("^(?:#{pattern.join('|')})$", true)
      end

      def valid_type(type)
        available_types = %i[import export]
        type = type.to_sym
        raise Errors::InvalidPluginType, 'Invalid plugin type' unless available_types.include?(type)

        type
      end

      def template_for_trigger(trigger, type: :export)
        type = valid_type(type)
        plugs = plugins[type].clone
        plugs.delete_if { |t, o| o[:templates].nil? }.each do |_, options|
          options[:templates].each do |t|
            if trigger =~ /^(?:#{t[:trigger].normalize_trigger})$/
              return options[:class].template(trigger)
            end
          end
        end
        raise Errors::InvalidArgument, "No template type matched \"#{trigger}\""
      end
    end
  end
end
