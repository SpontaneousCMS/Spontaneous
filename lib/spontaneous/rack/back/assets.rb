require 'sprockets'

module Spontaneous::Rack::Back
  class Assets < Base
    def initialize(app)
      css, js = %w(css js).map { |d| build_asset_handler(d) }
      assets = Spontaneous::Rack::CacheableFile.new(Spontaneous.root / "public/@spontaneous/assets")
      @app = ::Rack::Builder.app do
        use Spontaneous::Rack::Static, :root => Spontaneous.application_dir, :urls => %W(/static)
        map("/assets") { run assets }
        map("/css")    { run css }
        map("/js")     { run js }
        run app
      end
    end

    def call(env)
      @app.call(env)
    end

    def build_asset_handler(dir)
      ::Sprockets::Environment.new(Spontaneous.application_dir ) do |environment|
        environment.append_path("#{dir}")
      end
    end
  end
end
