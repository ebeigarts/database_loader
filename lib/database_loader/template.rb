module DatabaseLoader
  class Template
    attr_accessor :contents

    def initialize(contents)
      self.contents = contents
    end

    def render(options = {})
      case DatabaseLoader.template_engine
      when :liquid
        require "liquid"
        Liquid::Template.parse(contents).render(options)
      when :erb
        require "erb"
        struct = OpenStruct.new(options)
        ERB.new(contents).result(struct.send(:binding))
      when :erubis
        require "erubis"
        struct = OpenStruct.new(options)
        Erubis::Eruby.new(contents).result(struct.send(:binding))
      else
        contents
      end
    end
  end
end
