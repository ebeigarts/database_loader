module DatabaseLoader
  class Railtie < Rails::Railtie
    rake_tasks do
      DatabaseLoader.set_schemas
      require "database_loader/tasks"
    end
  end
end
