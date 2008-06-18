module Nanoc::CLI

  class CreateSiteCommand < Command # :nodoc:

    DEFAULT_PAGE = <<EOS
<h1>A Brand New nanoc Site</h1>
<p>You&#8217;ve just created a new nanoc site. The page you are looking at right now is the home page for your site (and it&#8217;s probably the only page).</p>
<p>To get started, consider replacing this default homepage with your own customized homepage. Some pointers on how to do so:</p>
<ul>
  <li><strong>Change this page&#8217;s content</strong> by editing &#8220;content.txt&#8221; file in the &#8220;content&#8221; directory. This is the actual page content, and therefore doesn&#8217;t include the header, sidebar or style information (those are part of the layout).</li>
  <li><strong>Change the layout</strong>, which is the &#8220;default.txt&#8221; file in the &#8220;layouts/default&#8221; directory, and create something unique (and hopefully less bland).</li>
</ul>
<p>If you need any help with customizing your nanoc web site, be sure to check out the documentation (see sidebar), and be sure to subscribe to the discussion group (also see sidebar). Enjoy!</p>
EOS

    DEFAULT_LAYOUT = <<EOS
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <title>A Brand New nanoc Site - <%= @page.title %></title>
    <style type="text/css" media="screen">
      * {
        margin: 0;
        padding: 0;

        font-family: Helvetica, Arial, sans-serif;
      }

      body {
        background: #ccc;
      }

      a {
        text-decoration: none;
      }

      a:link,
      a:visited {
        color: #f30;
      }

      a:hover {
        color: #f90;
      }

      #main {
        position: absolute;

        top: 20px;
        left: 20px;

        padding: 30px 40px 20px 20px;

        width: 580px;

        border-top: 10px solid #f90;

        background: #fff;
      }

      #main h1 {
        font-size: 50px;

        letter-spacing: -3px;

        border-bottom: 3px solid #f30;

        padding-bottom: 7px;
        margin-bottom: 20px;
      }

      #main p {
        margin-top: 20px;

        font-size: 16px;

        line-height: 20px;

        color: #333;
      }

      #main strong {
        text-transform: uppercase;

        font-size: 14px;

        color: #000;
      }

      #main ul {
        margin: 20px 0;
      }

      #main li {
        margin: 20px 0 20px 20px;

        font-size: 16px;

        line-height: 20px;

        color: #333;
      }

      #sidebar {
        position: absolute;

        top: 60px;
        left: 640px;

        width: 220px;

        padding: 10px 10px 0 10px;

        border-top: 6px solid #f30;

        background: #eee;
      }

      #sidebar h2 {
        font-size: 14px;

        text-transform: uppercase;

        color: #333;

        line-height: 20px;
      }

      #sidebar ul {
        padding: 10px 0;
      }

      #sidebar li {
        font-size: 14px;
        line-height: 20px;

        list-style-type: none;
      }
    </style>
  </head>
  <body>
    <div id="main">
<%= @page.content %>
    </div>
    <div id="sidebar">
      <h2>Documentation</h2>
      <ul>
        <li><a href="http://nanoc.stoneship.org/help/tutorial/">Tutorial</a></li>
        <li><a href="http://nanoc.stoneship.org/help/manual/">Manual</a></li>
      </ul>
      <h2>Community</h2>
      <ul>
        <li><a href="http://groups.google.com/group/nanoc/">Discussion Group</a></li>
        <li><a href="http://groups.google.com/group/nanoc-es/">Discussion Group (Spanish)</a></li>
        <li><a href="http://nanoc.stoneship.org/trac/">Wiki</a></li>
      </ul>
    </div>
  </body>
</html>
EOS

    def name
      'create_site'
    end

    def aliases
      [ 'cs' ]
    end

    def short_desc
      'create a site'
    end

    def long_desc
      'Create a new site at the given path. The site will use the ' +
      'filesystem data source (but this can be changed later on). It will ' +
      'also include a few stub rakefiles to make adding new tasks easier.'
    end

    def usage
      "nanoc create_site [path]"
    end

    def option_definitions
      [
        # --datasource
        {
          :long => 'datasource', :short => 'd', :argument => :required,
          :desc => 'specify the data source for the new site'
        }
      ]
    end

    def run(options, arguments)
      # Check arguments
      if arguments.length != 1
        puts "usage: #{usage}"
        exit 1
      end

      # Extract arguments and options
      path        = arguments[0]
      data_source = options[:datasource] || 'filesystem'

      # Check whether site exists
      if File.exist?(path)
        puts "A site at '#{path}' already exists."
        exit 1
      end

      # Check whether data source exists
      if Nanoc::PluginManager.instance.data_source(data_source.to_sym).nil?
        puts "Unrecognised data source: #{data_source}"
        exit 1
      end

      # Setup notifications
      Nanoc::NotificationCenter.on(:file_created) do |file_path|
        Nanoc::CLI::Logger.instance.file(:high, :create, file_path)
      end

      # Build entire site
      FileUtils.mkdir_p(path)
      in_dir([path]) do
        site_create_minimal(data_source)
        site_setup
        site_populate
      end

      puts "Created a blank nanoc site at '#{path}'. Enjoy!" unless ENV['QUIET']
    end

  protected

    # Creates a configuration file and a output directory for this site, as
    # well as a rakefile and a 'tasks' directory because raking is fun.
    def site_create_minimal(data_source)
      # Create output
      FileUtils.mkdir_p('output')

      # Create config
      File.open('config.yaml', 'w') do |io|
        io.write "output_dir:  \"output\"\n"
        io.write "data_source: \"#{data_source}\"\n"
        io.write "router:      \"default\"\n"
      end
      Nanoc::NotificationCenter.post(:file_created, 'config.yaml')

      # Create rakefile
      File.open('Rakefile', 'w') do |io|
        io.write "Dir['tasks/**/*.rake'].sort.each { |rakefile| load rakefile }\n"
        io.write "\n"
        io.write "task :default do\n"
        io.write "  puts 'This is an example rake task.'\n"
        io.write "end\n"
      end
      Nanoc::NotificationCenter.post(:file_created, 'Rakefile')

      # Create tasks
      FileUtils.mkdir_p('tasks')
      File.open('tasks/default.rake', 'w') do |io|
        io.write "task :example do\n"
        io.write "  puts 'This is an example rake task in tasks/default.rake.'\n"
        io.write "end\n"
      end
      Nanoc::NotificationCenter.post(:file_created, 'tasks/default.rake')
    end

    # Sets up the site's data source, i.e. creates the bare essentials for
    # this data source to work.
    def site_setup
      # Get site
      site = Nanoc::Site.new(YAML.load_file('config.yaml'))

      # Set up data source
      site.data_source.loading do
        site.data_source.setup
      end
    end

    # Populates the site with some initial data, such as a root page, a
    # default layout, a default template, and so on.
    def site_populate
      # Get site
      site = Nanoc::Site.new(YAML.load_file('config.yaml'))

      # Create page
      page = Nanoc::Page.new(
        DEFAULT_PAGE,
        { :title => 'Home' },
        '/'
      )
      page.site = site
      page.save

      # Fill page defaults
      Nanoc::Page::DEFAULTS.each_pair do |key, value|
        site.page_defaults.attributes[key] = value
      end
      site.page_defaults.save

      # Create layout
      layout = Nanoc::Layout.new(
        DEFAULT_LAYOUT,
        { :filter => 'erb' },
        '/default/'
      )
      layout.site = site
      layout.save

      # Create template
      template = Nanoc::Template.new(
        "Hi, I'm a new page!\n",
        { :title => "A New Page" },
        'default'
      )
      template.site = site
      template.save

      # Fill code
      code = Nanoc::Code.new(
        "\# All files in the 'lib' directory will be loaded\n" +
        "\# before nanoc starts compiling.\n" +
        "\n" +
        "def html_escape(str)\n" +
        "  str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('\"', '&quot;')\n" +
        "end\n" +
        "alias h html_escape\n"
      )
      code.site = site
      code.save
    end

  end

end
