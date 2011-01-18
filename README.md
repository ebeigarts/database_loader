Database Loader
===============

Load SQL views, materialized views, grants, etc. into database.

For tables, use Rails migrations.

Currently it works only with **oracle_enahanced** adapter.

## Installation

Include the gem in your Gemfile:

    gem "database_loader"

In Rails 2.x you also need to add this to you Rakefile

    require "database_loader/tasks"

## Structure

    rails_app/
      db/
        migrate/
        sql/
          local/
            views/
              report_v.sql
          ext/
            packages/
              sync_api.sql
            views/
              users_v.sql
            materialized_views/
            indexes/
            functions/
            scripts/
            grants/

## Load generated SQL into database

    rake db:sql:load:local
    rake db:sql:load:ext

## Preview generated SQL

    rake db:sql:dump:local
    rake db:sql:dump:ext

## Packaging a new release

In case you cannot directly access your external database,
you can generate a package containing all your SQL files and send it to DBA.

    rake db:sql:package:local NAME="v1"
    rake db:sql:package:ext NAME="v1"

## Configuration

config/initializers/database_loader.rb

    # Types that contain SQL files.
    DatabaseLoader.types = [ :views, :materialized_views, :indexes, :packages, :functions, :scripts, :grants ]

    # Use :erb, :erubis or :liquid to render SQL files.
    DatabaseLoader.template_engine = :erb

    # Path to store generated tar packages.
    DatabaseLoader.package_path = "/tmp"

    # Path to SH template that will be used to generate deployement script (see examples/template.sh)
    DatabaseLoader.template_path = Rails.root.join("db", "sql", "template.sh")

## Setting up database connections

Convention is to create additional configurations for
each environment and append the external schema name.

config/database.yml

    development:
      username: local
      password: ...

    development_ext:
      username: external
      password: ...


## TODO

* SQL dependency handling.

