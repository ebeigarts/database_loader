$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__))) unless $LOAD_PATH.include?(File.expand_path(File.dirname(__FILE__)))

require "tmpdir"
require "ostruct"

require "database_loader/version"

module DatabaseLoader
  def self.set_schemas
    if Rails.root
      self.schemas = Dir[File.expand_path("#{Rails.root}/db/sql/*")].select { |d| File.directory?(d) }.map { |d| File.basename(d).to_sym }
    else
      self.schemas = [:local]
    end
  end

  # Schemas that contain SQL files. :local will be used to load in SQL files in current database.
  mattr_accessor :schemas
  self.set_schemas

  # Folders that contain SQL files.
  mattr_accessor :types
  self.types = [ :views, :materialized_views, :indexes, :packages, :functions, :scripts, :grants ]

  # Use :erb, :erubis or :liquid to render SQL files.
  mattr_accessor :template_engine
  self.template_engine = :erb

  # Path to store generated deployement packages.
  mattr_accessor :package_path
  self.package_path = Dir.tmpdir

  # Path to SH template that will be used to generate deployement script.
  mattr_accessor :template_path
  self.template_path = File.dirname(__FILE__) + "/../../examples"

  def self.files(schema, type = nil, name = nil)
    type ||= "**"
    name ||= "*"
    files = []
    Dir[File.expand_path("#{Rails.root}/db/sql/#{schema}/#{type}")].each do |dir_path|
      if DatabaseLoader.types.include?(File.basename(dir_path).to_sym)
        Dir["#{dir_path}/#{name}.sql"].sort.each do |path|
          files << SqlFile.new(path)
        end
        Dir["#{dir_path}/#{name}.rb"].sort.each do |path|
          files << RubyFile.new(path)
        end
      end
    end
    files
  end

  def self.invalid_objects
    ActiveRecord::Base.connection.select_all(%{
      SELECT object_name AS name, object_type AS type, status
      FROM user_objects
      WHERE object_name LIKE '#{ActiveRecord::Base.table_name_prefix[0..-2].upcase}%'
        AND status = 'INVALID'
        AND object_type like 'PACKAGE%'
    })
  end

  def self.errors
    ActiveRecord::Base.connection.select_all(%{
      SELECT *
      FROM USER_ERRORS
      WHERE name LIKE '#{ActiveRecord::Base.table_name_prefix[0..-2].upcase}%'
      ORDER BY name, type, sequence
    })
  end

  def self.enable_dbms_output
    plsql.dbms_output.enable(10_000)
  end

  def self.dbms_output
    loop do
      result = plsql.dbms_output.get_line(:line => '', :status => 0)
      break unless result[:status] == 0
      yield result[:line]
    end
  end

  def self.connect_as(schema)
    begin
      connection_config = ActiveRecord::Base.connection.raw_connection.instance_variable_get("@config").symbolize_keys
      connection_name = nil
      # When running rake test|spec RAILS_ENV is development by default,
      # so we need to guess config from current connection.
      ActiveRecord::Base.configurations.each do |name, config|
        # current configuration?
        if connection_config.symbolize_keys == config.symbolize_keys
          # current configuration has also _apps configuration?
          if ActiveRecord::Base.configurations.any? { |other_name, _| other_name.to_s == "#{name}_#{schema}" }
            connection_name = name
            break
          end
        end
      end
      if schema != :local
        unless connection_name
          raise "Missing database.yml configuration for <RAILS_ENV>_#{schema}."
        end
        puts "* Loading SQL statements in #{connection_name.downcase}_apps"
        ActiveRecord::Base.establish_connection("#{connection_name}_#{schema}".to_sym)
      end
      yield connection_config
    ensure
      if schema != :local
        # Set back the original connection
        ActiveRecord::Base.establish_connection(connection_name)
      end
    end
  end

  autoload :SqlFile,      'database_loader/sql_file'
  autoload :RubyFile,     'database_loader/ruby_file'
  autoload :SqlStatement, 'database_loader/sql_statement'
  autoload :Template,     'database_loader/template'
end

require "database_loader/railtie" if defined?(::Rails::Railtie)
