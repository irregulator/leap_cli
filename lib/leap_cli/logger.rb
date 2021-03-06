#
# A drop in replacement for Capistrano::Logger that integrates better with LEAP CLI.
#

require 'capistrano/logger'

#
# from Capistrano::Logger
# =========================
#
# IMPORTANT = 0
# INFO      = 1
# DEBUG     = 2
# TRACE     = 3
# MAX_LEVEL = 3
# COLORS = {
#   :none     => "0",
#   :black    => "30",
#   :red      => "31",
#   :green    => "32",
#   :yellow   => "33",
#   :blue     => "34",
#   :magenta  => "35",
#   :cyan     => "36",
#   :white    => "37"
# }
# STYLES = {
#   :bright     => 1,
#   :dim        => 2,
#   :underscore => 4,
#   :blink      => 5,
#   :reverse    => 7,
#   :hidden     => 8
# }
#

module LeapCli
  class Logger < Capistrano::Logger

    def initialize(options={})
      @options = options
      @level = options[:level] || 0
      @message_buffer = nil
    end

    def log(level, message, line_prefix=nil, options={})
      if message !~ /\n$/ && level <= 2 && line_prefix.is_a?(String)
        # in some cases, when the message doesn't end with a return, we buffer it and
        # wait until we encounter the return before we log the message out.
        @message_buffer ||= ""
        @message_buffer += message
        return
      elsif @message_buffer
        message = @message_buffer + message
        @message_buffer = nil
      end

      options[:level] ||= level
      [:stdout, :log].each do |mode|
        LeapCli::log_raw(mode) do
          message_lines(mode, message, line_prefix, options)
        end
      end
    end

    private

    def message_lines(mode, message, line_prefix, options)
      formatted_message, formatted_prefix, message_options = apply_formatting(mode, message, line_prefix, options)
      if message_options[:level] <= self.level && formatted_message && formatted_message.chars.any?
        if formatted_prefix
          formatted_message.lines.collect { |line|
            "[#{formatted_prefix}] #{line.sub(/\s+$/, '')}"
          }
        else
          formatted_message.lines.collect {|line| line.sub(/\s+$/, '')}
        end
      else
        nil
      end
    end

    ##
    ## FORMATTING
    ##

    @formatters = [
      # TRACE
      { :match => /command finished/,          :color => :white,   :style => :dim, :match_level => 3, :priority => -10 },
      { :match => /executing locally/,         :color => :yellow,  :match_level => 3, :priority => -20 },

      # DEBUG
      #{ :match => /executing .*/,             :color => :green,   :match_level => 2, :priority => -10, :timestamp => true },
      #{ :match => /.*/,                        :color => :yellow,  :match_level => 2, :priority => -30 },
      { :match => /^transaction:/,             :level => 3 },

      # INFO
      { :match => /.*out\] (fatal:|ERROR:).*/, :color => :red,     :match_level => 1, :priority => -10 },
      { :match => /Permission denied/,         :color => :red,     :match_level => 1, :priority => -20 },
      { :match => /sh: .+: command not found/, :color => :magenta, :match_level => 1, :priority => -30 },

      # IMPORTANT
      { :match => /^err ::/,                   :color => :red,     :match_level => 0, :priority => -10 },
      { :match => /^ERROR:/,                   :color => :red,     :match_level => 0, :priority => -10 },
      { :match => /.*/,                        :color => :blue,    :match_level => 0, :priority => -20 },

      # CLEANUP
      { :match => /\s+$/,                      :replace => '', :priority => 0},

      # DEBIAN PACKAGES
      { :match => /^(Hit|Ign) /,                :color => :green,   :priority => -20},
      { :match => /^Err /,                      :color => :red,     :priority => -20},
      { :match => /^W(ARNING)?: /,              :color => :yellow,  :priority => -20},
      { :match => /^E: /,                       :color => :red,     :priority => -20},
      { :match => /already the newest version/, :color => :green,   :priority => -20},
      { :match => /WARNING: The following packages cannot be authenticated!/, :color => :red, :level => 0, :priority => -10},

      # PUPPET
      { :match => /^warning: .*is deprecated.*$/,  :level => 2, :color => :yellow, :priority => -10},
      { :match => /^warning: Scope.*$/,            :level => 2, :color => :yellow, :priority => -10},
      { :match => /^notice:/,                      :level => 1, :color => :cyan,   :priority => -20},
      { :match => /^notice:.*executed successfully$/, :level => 2, :color => :cyan, :priority => -15},
      { :match => /^warning:/,                     :level => 0, :color => :yellow, :priority => -20},
      { :match => /^Duplicate declaration:/,       :level => 0, :color => :red,    :priority => -20},
      { :match => /Finished catalog run/,          :level => 0, :color => :green,  :priority => -10},
      { :match => /^Puppet apply complete \(changes made\)/, :level => 0, :color => :green,  :priority => -10},
      { :match => /^Puppet apply complete \(no changes\)/, :level => 0, :color => :green,  :priority => -10},

      # PUPPET FATAL ERRORS
      { :match => /^err:/,                         :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Failed to parse template/,     :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Parameter matches failed:/,    :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Syntax error/,                 :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Cannot reassign variable/,     :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Could not find template/,      :level => 0, :color => :red, :priority => -1, :exit => 1},
      { :match => /^Puppet apply complete.*fail/,  :level => 0, :color => :red, :priority => -1, :exit => 1},

      # TESTS
      { :match => /^PASS: /,                :color => :green,   :priority => -20},
      { :match => /^(FAIL|ERROR): /,        :color => :red,     :priority => -20},
      { :match => /^SKIP: /,                :color => :yellow,  :priority => -20}

    ]

    def self.sorted_formatters
      # Sort matchers in reverse order so we can break if we found a match.
      @sorted_formatters ||= @formatters.sort_by { |i| -(i[:priority] || i[:prio] || 0) }
    end

    @prefix_formatters = [
      { :match => /(err|out) :: /,             :replace => '', :priority => 0},
      { :match => /\s+$/,                      :replace => '', :priority => 0}
    ]
    def self.prefix_formatters; @prefix_formatters; end

    def apply_formatting(mode, message, line_prefix = nil, options={})
      message = message.dup
      options = options.dup
      if !line_prefix.nil?
        if !line_prefix.is_a?(String)
          line_prefix = line_prefix.to_s.dup
        else
          line_prefix = line_prefix.dup
        end
      end
      color = options[:color] || :none
      style = options[:style]

      if line_prefix
        self.class.prefix_formatters.each do |formatter|
          if line_prefix =~ formatter[:match] && formatter[:replace]
            line_prefix.gsub!(formatter[:match], formatter[:replace])
          end
        end
      end

      self.class.sorted_formatters.each do |formatter|
        if (formatter[:match_level] == level || formatter[:match_level].nil?)
          if message =~ formatter[:match]
            options[:level] = formatter[:level] if formatter[:level]
            color = formatter[:color] if formatter[:color]
            style = formatter[:style] || formatter[:attribute] # (support original cap colors)

            message.gsub!(formatter[:match], formatter[:replace]) if formatter[:replace]
            message.replace(formatter[:prepend] + message) unless formatter[:prepend].nil?
            message.replace(message + formatter[:append])  unless formatter[:append].nil?
            message.replace(Time.now.strftime('%Y-%m-%d %T') + ' ' + message) if formatter[:timestamp]

            if formatter[:exit]
              LeapCli::Util.exit_status(formatter[:exit])
            end

            # stop formatting, unless formatter was just for string replacement
            break unless formatter[:replace]
          end
        end
      end

      if color == :hide
        return nil
      elsif mode == :log || (color == :none && style.nil?) || !LeapCli.log_in_color
        return [message, line_prefix, options]
      else
        term_color = COLORS[color]
        term_style = STYLES[style]
        if line_prefix.nil?
          message.replace format(message, term_color, term_style)
        else
          line_prefix.replace format(line_prefix, term_color, term_style).strip # format() appends a \n
        end
        return [message, line_prefix, options]
      end
    end

  end
end
