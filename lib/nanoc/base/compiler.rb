module Nanoc
  class Compiler

    attr_reader :stack, :config, :pages, :page_defaults

    def initialize
      @filters            = {}
      @layout_processors  = {}
    end

    def run!(pages, page_defaults, config)
      # Store what's necessary
      @page_defaults = page_defaults
      @config        = config
      @pages         = pages

      # Require all Ruby source files in lib/
      Dir['lib/**/*.rb'].sort.each { |f| require f }

      # Create output directory if necessary
      FileUtils.mkdir_p(@config[:output_dir])

      # Filter, layout, and filter again
      filter(:pre)
      layout
      filter(:post)

      # Save pages
      write_pages
    end

    # Filter and layout processor management

    def register_filter(name, &block)
      @filters[name.to_sym] = block
    end

    def filter_named(name)
      @filters[name.to_sym]
    end

    def register_layout_processor(extension, &block)
      @layout_processors[extension.to_s.sub(/^\./, '').to_sym] = block
    end

    def layout_processor_for_extension(extension)
      @layout_processors[extension.to_s.sub(/^\./, '').to_sym]
    end

  private

    # Main methods

    def filter(stage)
      # Reinit
      @stack = []

      # Prepare pages
      @pages.each do |page|
        page.stage        = stage
        page.is_filtered  = false
      end

      # Give feedback
      print_immediately "Filtering pages #{stage == :pre ? '(first pass) ' : '(second pass)'} "
      time_before = Time.now

      # Filter pages
      @pages.each do |page|
        # Give feedback
        print_immediately '.'

        # Filter
        begin
          page.filter!
        rescue => exception
          handle_exception(exception, "filtering page '#{page.path}'")
        end
      end

      # Give feedback
      print_immediately " [#{format('%.2f', Time.now - time_before)}s]\n"
    end

    def layout
      # Give feedback
      print_immediately 'Layouting pages               '
      time_before = Time.now

      # For each page (ignoring drafts)
      @pages.reject { |page| page.skip_output? }.each do |page|
        # Give feedback
        print_immediately '.'

        # Layout
        begin
          page.layout!
        rescue => exception
          handle_exception(exception, "layouting page '#{page.path}' in layout '#{page.layout}'")
        end
      end

      # Give feedback
      print_immediately ' ' * @pages.select { |page| page.skip_output? }.size
      print_immediately " [#{format('%.2f', Time.now - time_before)}s]\n"
    end

    def write_pages
      @pages.reject { |page| page.skip_output? }.each do |page|
        FileManager.create_file(page.path_on_filesystem) { page.content }
      end
    end

  end
end
