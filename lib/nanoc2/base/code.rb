module Nanoc2

  # Nanoc2::Code represent the custom code of a nanoc site. It contains the
  # textual source code as well as a mtime, which is used to speed up site
  # compilation.
  class Code

    # The Nanoc2::Site this code belongs to.
    attr_accessor :site

    # The textual source code representation.
    attr_reader :data

    # The time where the code was last modified.
    attr_reader :mtime

    # Creates a new code object. +data+ is the raw source code, which will be
    # executed before compilation. +mtime+ is the time when the code was last
    # modified (optional).
    def initialize(data, mtime=nil)
      @data  = data
      @mtime = mtime
    end

    # Loads the code by executing it.
    def load
      eval(@data, TOPLEVEL_BINDING)
    end

    # Saves the code in the database, creating it if it doesn't exist yet or
    # updating it if it already exists. Tells the site's data source to save
    # the code.
    def save
      @site.data_source.loading do
        @site.data_source.save_code(self)
      end
    end

  end

end