module DatabaseLoader
  class SqlStatement
    attr_accessor :contents

    def initialize(contents)
      self.contents = contents
    end

    def excerpt
      text = contents.gsub(/\-\-[^\r\n]*/, "").squish
      if text.size > 60
        "#{text.first(60)} ..."
      else
        text
      end
    end

    def execute
      ActiveRecord::Base.connection.execute(contents)
    end

    def to_s
      contents
    end
  end
end
