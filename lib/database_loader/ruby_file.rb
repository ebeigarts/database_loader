module DatabaseLoader
  class RubyFile < SqlFile
    def render
      "-- Cannot dump ruby file"
    end
    alias_method :to_s, :render
    
    def excerpt
      "#{read.first(60)} ..."
    end
    
    def statements
      [self]
    end
    
    def execute
      content = read
      ActiveRecord::Schema.define do
        instance_eval(content)
      end
    end
  end
end