# frozen_string_literal: true

# Cribbed from <https://github.com/flori/term-ansicolor>
module Doing
  # Terminal color functions
  module Color
    # :stopdoc:
    ATTRIBUTES = [
      [:clear,               0], # String#clear is already used to empty string in Ruby 1.9
      [:reset,               0], # synonym for :clear
      [:bold,                1],
      [:dark,                2],
      [:italic,              3], # not widely implemented
      [:underline,           4],
      [:underscore,          4], # synonym for :underline
      [:blink,               5],
      [:rapid_blink,         6], # not widely implemented
      [:negative,            7], # no reverse because of String#reverse
      [:concealed,           8],
      [:strikethrough,       9], # not widely implemented
      [:strike,              9], # not widely implemented
      [:black,              30],
      [:red,                31],
      [:green,              32],
      [:yellow,             33],
      [:blue,               34],
      [:magenta,            35],
      [:purple,             35],
      [:cyan,               36],
      [:white,              37],
      [:bgblack,            40],
      [:bgred,              41],
      [:bggreen,            42],
      [:bgyellow,           43],
      [:bgblue,             44],
      [:bgmagenta,          45],
      [:bgpurple,           45],
      [:bgcyan,             46],
      [:bgwhite,            47],
      [:boldblack,          90],
      [:boldred,            91],
      [:boldgreen,          92],
      [:boldyellow,         93],
      [:boldblue,           94],
      [:boldmagenta,        95],
      [:boldpurple,         95],
      [:boldcyan,           96],
      [:boldwhite,          97],
      [:boldbgblack,       100],
      [:boldbgred,         101],
      [:boldbggreen,       102],
      [:boldbgyellow,      103],
      [:boldbgblue,        104],
      [:boldbgmagenta,     105],
      [:boldbgpurple,      105],
      [:boldbgcyan,        106],
      [:boldbgwhite,       107],
      [:softpurple,  '0;35;40'],
      [:hotpants,    '7;34;40'],
      [:knightrider, '7;30;40'],
      [:flamingo,    '7;31;47'],
      [:yeller,      '1;37;43'],
      [:whiteboard,  '1;30;47'],
      [:chalkboard,  '1;37;40'],
      [:led,         '0;32;40'],
      [:redacted,    '0;30;40'],
      [:alert,       '1;31;43'],
      [:error,       '1;37;41'],
      [:default,        '0;39']
    ].map(&:freeze).freeze

    ATTRIBUTE_NAMES = ATTRIBUTES.transpose.first

    # Returns true if Doing::Color supports the +feature+.
    #
    # The feature :clear, that is mixing the clear color attribute into String,
    # is only supported on ruby implementations, that do *not* already
    # implement the String#clear method. It's better to use the reset color
    # attribute instead.
    def support?(feature)
      case feature
      when :clear
        !String.instance_methods(false).map(&:to_sym).include?(:clear)
      end
    end

    # Template coloring
    class ::String
      ##
      ## Extract the longest valid %color name from a string.
      ##
      ## Allows %colors to bleed into other text and still
      ## be recognized, e.g. %greensomething still finds
      ## %green.
      ##
      ## @return     [String] a valid color name
      ##
      def validate_color
        valid_color = nil
        compiled = ''
        normalize_color.split('').each do |char|
          compiled += char
          valid_color = compiled if Color.attributes.include?(compiled.to_sym)
        end

        valid_color
      end

      ##
      ## Normalize a color name, removing underscores,
      ## replacing "bright" with "bold", and converting
      ## bgbold to boldbg
      ##
      ## @return     [String] Normalized color name
      ##
      def normalize_color
        gsub(/_/, '').sub(/bright/i, 'bold').sub(/bgbold/, 'boldbg')
      end
    end

    class << self
      # Returns true, if the coloring function of this module
      # is switched on, false otherwise.
      def coloring?
        @coloring
      end

      # Turns the coloring on or off globally, so you can easily do
      # this for example:
      #  Doing::Color::coloring = STDOUT.isatty
      attr_writer :coloring

      def coloring
        @coloring ||= true
      end
    end

    ATTRIBUTES.each do |c, v|
      eval <<-EOT
        def #{c}(string = nil)
          result = ''
          result << "\e[#{v}m" if Doing::Color.coloring?
          if block_given?
            result << yield
          elsif string.respond_to?(:to_str)
            result << string.to_str
          elsif respond_to?(:to_str)
            result << to_str
          else
            return result #only switch on
          end
          result << "\e[0m" if Doing::Color.coloring?
          result
        end
      EOT

      # Accept brightwhite in addition to boldwhite
      if c =~ /bold/
        eval <<-EOT
          def #{c.to_s.sub(/bold/, 'bright')}(string = nil)
            result = ''
            result << "\e[#{v}m" if Doing::Color.coloring?
            if block_given?
              result << yield
            elsif string.respond_to?(:to_str)
              result << string.to_str
            elsif respond_to?(:to_str)
              result << to_str
            else
              return result #only switch on
            end
            result << "\e[0m" if Doing::Color.coloring?
            result
          end
        EOT
      end
    end

    # Regular expression that is used to scan for ANSI-sequences while
    # uncoloring strings.
    COLORED_REGEXP = /\e\[(?:(?:[349]|10)[0-7]|[0-9])?m/

    # Returns an uncolored version of the string, that is all
    # ANSI-sequences are stripped from the string.
    def uncolor(string = nil) # :yields:
      if block_given?
        yield.to_str.gsub(COLORED_REGEXP, '')
      elsif string.respond_to?(:to_str)
        string.to_str.gsub(COLORED_REGEXP, '')
      elsif respond_to?(:to_str)
        to_str.gsub(COLORED_REGEXP, '')
      else
        ''
      end
    end

    module_function

    # Returns an array of all Doing::Color attributes as symbols.
    def attributes
      ATTRIBUTE_NAMES
    end
    extend self
  end
end
