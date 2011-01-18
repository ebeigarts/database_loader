module DatabaseLoader
  class SqlFile
    attr_accessor :path, :username

    def initialize(path)
      self.path = path
    end

    def type
      path.split(/[\/\\]/)[-2].to_sym
    end

    def name
      File.basename(path)
    end

    def read
      File.read(path)
    end

    def render
      Template.new(read).render("username" => username)
    end
    alias_method :to_s, :render

    def statements
      render.split(/\r?\n\/\r?\n/).reject(&:blank?).map do |str|
        SqlStatement.new(str)
      end
    end
  end
end
