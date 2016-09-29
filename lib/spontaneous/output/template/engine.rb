
module Spontaneous::Output::Template
  class PublishEngine
    # Should be initialized with the Site template roots
    def initialize(template_roots, cache = Spontaneous::Output.cache_templates?)
      @engine = template_engine_class(cache).new(template_roots, syntax)
      # disabled until I figure out where to write compiled scripts when using a
      # non-File based template store
      self.write_compiled_scripts = false # Spontaneous::Output.write_compiled_scripts?
    end

    def write_compiled_scripts=(state)
      @engine.write_compiled_scripts = state if @engine.respond_to?(:write_compiled_scripts=)
    end

    def syntax
      PublishSyntax
    end

    def roots
      @engine.roots
    end

    def render(content, context, format = :html)
      render_template(template_path(content, format), context, format)
    end

    def render_template(template_path, context, format = :html)
      @engine.render(template_path, context, format)
    end

    def render_string(template_string, context, format = :html)
      @engine.render_string(template_string, context, format)
    end

    def template_path(content, format)
      content.template(format, self)
    end

    def template_exists?(template, format)
      @engine.template_exists?(template, format)
    end

    def template_location(template, format)
      @engine.template_location(template, format)
    end

    def dynamic_template?(template_string)
      @engine.dynamic_template?(template_string)
    end

    def template_engine_class(cache)
      if cache
        cached_engine_class
      else
        uncached_engine_class
      end
    end

    def cached_engine_class
      Cutaneous::CachingEngine
    end

    def uncached_engine_class
      Cutaneous::Engine
    end
  end

  # Should be initialized with the path to the current rendered revision
  class RequestEngine < PublishEngine
    def syntax
      RequestSyntax
    end

    def template_path(content, format)
      path = content.path.gsub(%r{^/}, "")
      path = "index" if path.empty?
      path
    end
  end
end
