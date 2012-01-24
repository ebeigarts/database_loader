require "database_loader"

namespace :db do
  namespace :sql do
    namespace :load do
      DatabaseLoader.schemas.each do |schema|
        desc "Load SQL statements in #{schema}"
        task schema do
          DatabaseLoader.types.each do |type|
            Rake::Task["db:sql:load:#{schema}:#{type}"].invoke
          end
        end
        namespace schema do
          DatabaseLoader.types.each do |type|
            desc "Load SQL #{type.to_s.singularize} statements in #{schema}"
            task type => :environment do
              DatabaseLoader.connect_as(schema) do |connection_config|
                DatabaseLoader.enable_dbms_output
                DatabaseLoader.files(schema, type, ENV['NAME']).each do |file|
                  puts "* #{file.type}/#{file.name} ".ljust(80, "-")
                  file.username = connection_config[:username]
                  file.statements.each do |statement|
                    puts "  #{statement.excerpt}"
                    begin
                      statement.execute
                      DatabaseLoader.dbms_output do |line|
                        puts "! DBMS_OUTPUT: #{line}"
                      end
                    rescue => e
                      $stderr.puts e.message
                    end
                  end
                end
                DatabaseLoader.invalid_objects.each do |h|
                  puts "! #{h['name']} #{h['type']} #{h['status']}"
                end
                DatabaseLoader.errors.each do |h|
                  puts "! #{h['name']} #{h['type']} #{h['attribute']} at line #{h['line']}: #{h['text']}"
                end
              end
            end
          end
        end
      end
    end

    namespace :dump do
      DatabaseLoader.schemas.each do |schema|
        desc "Dump SQL statements in #{schema}"
        task schema do
          DatabaseLoader.types.each do |type|
            Rake::Task["db:sql:dump:#{schema}:#{type}"].invoke
          end
        end
        namespace schema do
          DatabaseLoader.types.each do |type|
            desc "Dump SQL #{type.to_s.singularize} statements in #{schema}"
            task type => :environment do
              connection_config = ActiveRecord::Base.connection.raw_connection.instance_variable_get("@config").symbolize_keys
              DatabaseLoader.files(schema, type, ENV['NAME']).each do |file|
                file.username = connection_config[:username]
                puts "-- #{file.type}/#{file.name} ".ljust(80, "-")
                puts file.to_s
                puts
              end
            end
          end
        end
      end
    end

    namespace :package do
      DatabaseLoader.schemas.each do |schema|
        desc "Package SQL files for remote installation in #{schema}. rake db:sql:package:#{schema} NAME=CM0000072322 COMMIT=master."
        task schema => :environment do
          unless ENV['NAME'].present?
            STDERR.puts "You have to specify NAME environment"
          end
          if ENV['COMMIT']
            files = `git diff --diff-filter=ACM --name-only #{ENV['COMMIT']} ./db/sql/#{schema}`.strip.split(/\n/).sort
          else
            files = `find ./db/sql/#{schema} -type f`.strip.split("\n").sort
          end
          connection_config = ActiveRecord::Base.connection.raw_connection.instance_variable_get("@config").symbolize_keys
          pkg_name = ENV['NAME']
          pkg_dir = File.join(DatabaseLoader.package_path, connection_config[:username].to_s.downcase)
          # Package SQL files
          mkdir_p(File.join(pkg_dir, pkg_name))
          Dir[File.join(pkg_dir, pkg_name) + "/*/"].each do |dir|
            rm_rf(dir)
          end
          DatabaseLoader.types.each do |type|
            DatabaseLoader.files(schema, type, "*").each do |file|
              next unless files.any? { |f| f.include?(file.name) }
              file.username = connection_config[:username]
              puts "-- #{file.type}/#{file.name} ".ljust(80, "-")
              sql = file.to_s
              sql += "\nEXIT\n" # tell sqlplus to exit
              # puts sql
              FileUtils.mkdir_p(File.join(pkg_dir, pkg_name, file.type.to_s))
              File.open(File.join(pkg_dir, pkg_name, file.type.to_s, file.name), "wb") { |f| f.write sql }
            end
          end
          # Generate shell script
          sh_content = DatabaseLoader::Template.new(File.read(DatabaseLoader.template_path)).render({
            "cm_number" => pkg_name.gsub(/[^\d]/, ''),
            "application" => connection_config[:username]
          })
          File.open(File.join(pkg_dir, pkg_name, "#{pkg_name}.sh"), "wb") { |f| f.write(sh_content) }
          # Generate summary
          if ENV['COMMIT']
            File.open(File.join(pkg_dir, pkg_name, "#{pkg_name}.txt"), "wb") do |f|
              f.write(`git diff --stat #{ENV['COMMIT']} ./db/sql/#{schema}`)
            end
            File.open(File.join(pkg_dir, pkg_name, "#{pkg_name}.diff"), "wb") do |f|
              f.write(`git diff #{ENV['COMMIT']} ./db/sql/#{schema}`)
            end
          end
          # Try to open the folder for manual reviewing
          system `open #{File.join(pkg_dir, pkg_name)}`
          # Cleanup & compress
          puts "Press return key to continue"; STDIN.getc
          Dir.chdir(pkg_dir)
          sh "tar cf #{pkg_name}.tar #{pkg_name}"
          ### print
          puts
          # puts "# export TWO_TASK=..."
          puts "Instructions for #{pkg_name}:"
          puts "$ tar vxf #{pkg_name}.tar"
          puts "$ cd #{pkg_name}"
          puts "$ sh #{pkg_name}.sh <#{connection_config[:username]}_user> <#{connection_config[:username]}_pwd> <#{schema}_user> <#{schema}_pwd>"
        end
      end
    end
  end
end
