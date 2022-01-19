# frozen_string_literal: true

module Doing
  # Chronify methods for strings
  class ::String
    ##
    ## Converts input string into a Time object when input
    ## takes on the following formats:
    ##             - interval format e.g. '1d2h30m', '45m'
    ##               etc.
    ##             - a semantic phrase e.g. 'yesterday
    ##               5:30pm'
    ##             - a strftime e.g. '2016-03-15 15:32:04
    ##               PDT'
    ##
    ## @param      options  Additional options
    ##
    ## @option options :future [Boolean] assume future date
    ##                                   (default: false)
    ##
    ## @option options :guess  [Symbol] :begin or :end to
    ##                                   assume beginning or end of
    ##                                   arbitrary time range
    ##
    ## @return     [DateTime] result
    ##
    def chronify(**options)
      now = Time.now
      raise InvalidTimeExpression, "Invalid time expression #{inspect}" if to_s.strip == ''

      secs_ago = if match(/^(\d+)$/)
                   # plain number, assume minutes
                   Regexp.last_match(1).to_i * 60
                 elsif (m = match(/^(?:(?<day>\d+)d)?(?:(?<hour>\d+)h)?(?:(?<min>\d+)m)?$/i))
                   # day/hour/minute format e.g. 1d2h30m
                   [[m['day'], 24 * 3600],
                    [m['hour'], 3600],
                    [m['min'], 60]].map { |qty, secs| qty ? (qty.to_i * secs) : 0 }.reduce(0, :+)
                 end

      if secs_ago
        now - secs_ago
      else
        Chronic.parse(self, {
                        guess: options.fetch(:guess, :begin),
                        context: options.fetch(:future, false) ? :future : :past,
                        ambiguous_time_range: 8
                      })
      end
    end

    ##
    ## Converts simple strings into seconds that can be
    ## added to a Time object
    ##
    ## Input string can be HH:MM or XX[dhm][[XXhm][XXm]]
    ## (1d2h30m, 45m, 1.5d, 1h20m, etc.)
    ##
    ## @return     [Integer] seconds
    ##
    def chronify_qty
      minutes = 0
      case self.strip
      when /^(\d+):(\d\d)$/
        minutes += Regexp.last_match(1).to_i * 60
        minutes += Regexp.last_match(2).to_i
      when /^(\d+(?:\.\d+)?)([hmd])?/
        scan(/(\d+(?:\.\d+)?)([hmd])?/).each do |m|
          amt = m[0]
          type = m[1].nil? ? 'm' : m[1]

          minutes += case type.downcase
                     when 'm'
                       amt.to_i
                     when 'h'
                       (amt.to_f * 60).round
                     when 'd'
                       (amt.to_f * 60 * 24).round
                     else
                       0
                     end
        end
      end
      minutes * 60
    end

    ##
    ## Convert DD:HH:MM to seconds
    ##
    ## @return     [Integer] rounded number of seconds
    ##
    def to_seconds
      mtch = match(/(\d+):(\d+):(\d+)/)

      raise Errors::DoingRuntimeError, "Invalid time string: #{self}" unless mtch

      h = mtch[1]
      m = mtch[2]
      s = mtch[3]
      (h.to_i * 60 * 60) + (m.to_i * 60) + s.to_i
    end

    ##
    ## Convert DD:HH:MM to a natural language string
    ##
    ## @param      format  [Symbol] The format to output (:dhm, :hm, :m, :clock, :natural)
    ##
    def time_string(format: :dhm)
      to_seconds.time_string(format: format)
    end

    ##
    ## Convert (chronify) natural language dates
    ## within configured date tags (tags whose value is
    ## expected to be a date). Modifies string in place.
    ##
    ## @param      additional_tags  [Array] An array of
    ##                              additional tags to
    ##                              consider date_tags
    ##
    def expand_date_tags(additional_tags = nil)
      iso_rx = /\d{4}-\d\d-\d\d \d\d:\d\d/

      watch_tags = [
        'start(?:ed)?',
        'beg[ia]n',
        'done',
        'finished',
        'completed?',
        'waiting',
        'defer(?:red)?'
      ]

      if additional_tags
        date_tags = additional_tags
        date_tags = date_tags.split(/ *, */) if date_tags.is_a?(String)
        date_tags.map! do |tag|
          tag.sub(/^@/, '').gsub(/\((?!\?:)(.*?)\)/, '(?:\1)').strip
        end
        watch_tags.concat(date_tags).uniq!
      end

      done_rx = /(?<=^| )@(?<tag>#{watch_tags.join('|')})\((?<date>.*?)\)/i

      gsub!(done_rx) do
        m = Regexp.last_match
        t = m['tag']
        d = m['date']
        future = t =~ /^(done|complete)/ ? false : true
        parsed_date = d =~ iso_rx ? Time.parse(d) : d.chronify(guess: :begin, future: future)
        parsed_date.nil? ? m[0] : "@#{t}(#{parsed_date.strftime('%F %R')})"
      end
    end

    ##
    ## Splits a range string and returns an array of
    ## DateTime objects as [start, end]. If only one date is
    ## given, end time is nil.
    ##
    ## @return     [Array<DateTime>] Start and end dates as
    ##             array
    ## @example    Process a natural language date range
    ## "mon 3pm to mon 5pm".split_date_range
    ##
    def split_date_range
      date_string = dup
      case date_string
      when / (to|through|thru|(un)?til|-+) /
        dates = date_string.split(/ (?:to|through|thru|(?:un)?til|-+) /)
        start = dates[0].chronify(guess: :begin)
        finish = dates[-1].chronify(guess: :end)
      else
        start = date_string.chronify(guess: :begin)
        finish = date_string.chronify(guess: :end)
      end

      raise InvalidTimeExpression, 'Unrecognized date string' unless start

      Doing.logger.debug('Parser:', "date range interpreted as #{start.strftime('%F %R')} -- #{finish ? finish.strftime('%F %R') : 'now'}")
      [start, finish]
    end
  end
end
