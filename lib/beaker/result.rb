module Beaker
  class Result
    attr_accessor :host, :cmd, :exit_code, :stdout, :stderr, :output,
                  :raw_stdout, :raw_stderr, :raw_output
    def initialize(host, cmd)
      @host       = host
      @cmd        = cmd
      @stdout     = ''
      @stderr     = ''
      @output     = ''
      @exit_code  = nil
    end

    # Ruby assumes chunked data (like something it receives from Net::SSH)
    # to be binary (ASCII-8BIT). We need to gather all chunked data and then
    # re-encode it as the default encoding it assumes for external text
    # (ie our test files and the strings they're trying to match Net::SSH's
    # output from)
    # This is also the lowest overhead place to normalize line endings, IIRC
    def finalize!
      @raw_stdout = @stdout
      @stdout     = normalize_line_endings( convert( @stdout ) )
      @raw_stderr = @stderr
      @stderr     = normalize_line_endings( convert( @stderr ) )
      @raw_output = @output
      @output     = normalize_line_endings( convert( @output ) )
    end

    def normalize_line_endings string
      return string.gsub(/\r\n?/, "\n")
    end

    def convert string
      if string.respond_to?( :force_encoding ) and defined?( Encoding )
        # We're running in >= 1.9 and we'll need to convert
        return string.force_encoding( Encoding.default_external )
      else
        # We're running in < 1.9 and Ruby doesn't care
        return string
      end
    end

    def log(logger)
      logger.debug "Exited: #{exit_code}" unless exit_code == 0
    end

    def filter_puppet_loglevel(loglevel)
      # valid loglevel in right order
      loglevels = ['debug', 'info', 'notice', 'warning', 'err', 'alert', 'emerg','crit']

      # check if loglevel is valid and get int
      if loglevels.include?(loglevel)
        loglevel=loglevels.index(loglevel)
      else
        loglevel=loglevels.index('warning')
      end

      # build re with loglevels
      re_loglevel_values = loglevels.map {|x| Regexp.escape(x)}.join('|')
      re_loglevels = /^(#{re_loglevel_values}):/

      # group logs
      output = []
      selected = false

      @output.lines.each do |line|
        line_nocolor = line.gsub(/\e\[[^m]*m/, '')
        match =  re_loglevels.match(line_nocolor)

        # only if new loglevel line
        if match
          # only wanted loglevels
          if loglevels.include?(match[1]) and  (loglevels.index(match[1]) >= loglevel)
            selected = true
          else
            selected = false
          end

        end

        output += [line] if selected

      end

      output
    end


    def formatted_output(limit=10,loglevel='warning')
      output=filter_puppet_loglevel(loglevel)
      output.last(limit).collect {|x| "\t" + x}.join('')
    end

    def exit_code_in?(range)
      range.include?(@exit_code)
    end
  end
end
