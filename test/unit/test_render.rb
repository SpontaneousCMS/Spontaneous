# encoding: UTF-8

require File.expand_path('../../test_helper', __FILE__)

require 'sinatra/base'

class RenderTest < MiniTest::Spec
  include Spontaneous

  def setup
    @site = setup_site
    @saved_engine_class = Spontaneous::Render.renderer_class
  end

  def teardown
    teardown_site
    Spontaneous::Render.renderer_class = @saved_engine_class
  end

  def template_root
    @template_root ||= File.expand_path(File.join(File.dirname(__FILE__), "../fixtures/templates"))
  end

  context "First render step" do
    setup do
      self.template_root = template_root
      Spontaneous::Render.renderer_class = Spontaneous::Render::PublishingRenderer

      class ::TemplateClass < Content
        field :title do
          def to_epub
            to_html
          end
        end
        field :description do
          def to_pdf
            "{#{value}}"
          end
          def to_epub
            to_html
          end
        end

        style :this_template
        style :another_template
      end
      @content = TemplateClass.new
      @content.style.should == TemplateClass.default_style
      @content.title = "The Title"
      @content.description = "The Description"
    end

    teardown do
      Object.send(:remove_const, :TemplateClass) rescue nil
    end

    should "be able to render themselves to HTML" do
      @content.render.should == "<html><title>The Title</title><body>The Description</body></html>\n"
    end

    should "be able to render themselves to PDF" do
      @content.render(:pdf).should == "<PDF><title>The Title</title><body>{The Description}</body></PDF>\n"
    end

    should "be able to render themselves to EPUB" do
      @content.render(:epub).should == "<EPUB><title>The Title</title><body>The Description</body></EPUB>\n"
    end

    context "piece trees" do
      setup do
        TemplateClass.style :complex_template, :default => true
        TemplateClass.box :bits
        @content = TemplateClass.new
        @content.title = "The Title"
        @content.description = "The Description"
        @child = TemplateClass.new
        @child.title = "Child Title"
        @child.description = "Child Description"
        @content.bits << @child
        @content.pieces.first.style = TemplateClass.get_style(:this_template)
      end
      teardown do
        Content.delete
      end

      should "be accessible through #content method" do
        @content.render.should == "<complex>\nThe Title\n<piece><html><title>Child Title</title><body>Child Description</body></html>\n</piece>\n</complex>\n"
      end

      should "cascade the chosen format to all subsequent #render calls" do
        @content.render(:pdf).should == "<pdf>\nThe Title\n<piece><PDF><title>Child Title</title><body>{Child Description}</body></PDF>\n</piece>\n</pdf>\n"
      end

      should "only show visible pieces" do
        child = TemplateClass.new
        child.title = "Child2 Title"
        child.description = "Child2 Description"
        @content << child
        @content.pieces.last.style = TemplateClass.get_style(:this_template)
        @content.pieces.last.hide!
        @content.render.should == "<complex>\nThe Title\n<piece><html><title>Child Title</title><body>Child Description</body></html>\n</piece>\n</complex>\n"
      end
    end

    context "boxes" do
      setup do
        TemplateClass.style :slots_template, :default => true
        TemplateClass.box :images
        @content = TemplateClass.new
        @content.title = "The Title"
        @content.description = "The Description"
        @child = TemplateClass.new
        @child.title = "Child Title"
        @child.description = "Child Description"
        @content.images << @child
        @content.images.first.style = TemplateClass.get_style(:this_template)
      end

      should "render boxes" do
        @content.render.should == "<boxes>\n  <img><html><title>Child Title</title><body>Child Description</body></html>\n</img>\n</boxes>\n"
      end
      should "render boxes to alternate formats" do
        @content.render(:pdf).should == "<boxes-pdf>\n  <img><PDF><title>Child Title</title><body>{Child Description}</body></PDF>\n</img>\n</boxes-pdf>\n"
      end
    end

    context "anonymous boxes" do
      setup do
        TemplateClass.style :anonymous_style, :default => true
        TemplateClass.box :images do
          field :introduction
        end

        class ::AnImage < Content; end
        AnImage.field :title
        AnImage.template '<img>#{title}</img>'

        @root = TemplateClass.new
        @root.images.introduction = "Images below:"
        @image1 = AnImage.new
        @image1.title = "Image 1"
        @image2 = AnImage.new
        @image2.title = "Image 2"
        @root.images << @image1
        @root.images << @image2
      end

      teardown do
        Object.send(:remove_const, :AnImage) rescue nil
      end

      should "render using anonymous style" do
        @root.render.should == "<root>\nImages below:\n<img>Image 1</img>\n<img>Image 2</img>\n</root>\n"
      end
    end

    context "default templates" do
      setup do
        TemplateClass.style :default_template_style, :default => true
        TemplateClass.box :images_with_template do
          field :introduction
        end

        class ::AnImage < Content; end
        AnImage.field :title
        AnImage.template '<img>#{title}</img>'

        @root = TemplateClass.new
        @root.images_with_template.introduction = "Images below:"
        @image1 = AnImage.new
        @image1.title = "Image 1"
        @image2 = AnImage.new
        @image2.title = "Image 2"
        @root.images_with_template << @image1
        @root.images_with_template << @image2
      end

      teardown do
        Object.send(:remove_const, :AnImage) rescue nil
      end

      should "render using default style if present" do
        @root.render.should == "<root>\nImages below:\n<images>\n  <img>Image 1</img>\n  <img>Image 2</img>\n</images>\n\n</root>\n"
      end
    end

    context "page styles" do
      setup do
        class ::PageClass < Page
          field :title, :string
        end
        # PageClass.box :things
        # PageClass.style :inline_style
        PageClass.layout :subdir_style
        PageClass.layout :standard_page
        @parent = PageClass.new
        @parent.title = "Parent"
      end

      teardown do
        Object.send(:remove_const, :PageClass) rescue nil
      end

      should "find page styles at root of templates dir" do
        @parent.layout = :standard_page
        @parent.render.should == "/Parent/\n"
      end

      should "find page styles in class sub dir" do
        @parent.layout = :subdir_style
        @parent.render.should == "<Parent>\n"
      end
    end

    context "pages as inline content" do

      setup do
        class ::PageClass < Page
          field :title, :string
        end
        # class ::PieceClass < Piece; end
        PageClass.box :things
        PageClass.layout :page_style
        PageClass.style :inline_style
        @parent = PageClass.new
        @parent.title = "Parent"
        @page = PageClass.new
        @page.title = "Child"
        @parent.things << @page
        @parent.save
        @page.save
      end

      teardown do
        Object.send(:remove_const, :PageClass) rescue nil
      end

      should "use style assigned by entry" do
        @parent.pieces.first.style.should == PageClass.default_style
        @parent.things.first.style.should == PageClass.default_style
      end

      should "use their default page style when accessed directly" do
        @page = PageClass[@page.id]
        @page.layout.should == PageClass.default_layout
        assert_correct_template(@parent, 'layouts/page_style')
        @page.render.should == "<html></html>\n"
      end

      should "persist sub-page style settings" do
        @parent = Page[@parent.id]
        @parent.pieces.first.style.should == PageClass.default_style
      end

      should "render using the inline style" do
        assert_correct_template(@parent.pieces.first, 'page_class/inline_style')
        @parent.pieces.first.render.should == "Child\n"
        @parent.things.render.should == "Child\n"
        @parent.render.should == "<html>Child\n</html>\n"
      end
    end

    context "params in templates" do
      setup do
        class ::TemplateParams < Page; end
        TemplateParams.field :image, :default => "/images/fromage.jpg"
        TemplateParams.layout :template_params
        @page = TemplateParams.new
      end
      teardown do
        Object.send(:remove_const, :TemplateParams) rescue nil
      end
      should "be passed to the render call" do
        @page.image.value.should == "/images/fromage.jpg"
        @page.image.src.should == "/images/fromage.jpg"
        @page.render.should =~ /alt="Smelly"/
      end
    end
  end
  context "Request rendering" do
    setup do
      self.template_root = template_root

      class ::PreviewRender < Page
        field :title, :string
      end
      PreviewRender.style :inline
      PreviewRender.box :images
      PreviewRender.field :description, :markdown
      @page = PreviewRender.new(:title => "PAGE", :description => "DESCRIPTION")
      # @page.stubs(:id).returns(24)
      @page.save
      @session = ::Rack::MockSession.new(::Sinatra::Application)
    end

    teardown do
      Object.send(:remove_const, :PreviewRender)
    end

    context "Preview render" do
      setup do
        Spontaneous::Render.renderer_class = Spontaneous::Render::PreviewRenderer
        PreviewRender.layout :preview_render
      end

      should "render all tags & include preview edit markers" do
        @page.render.should == <<-HTML
PAGE <p>DESCRIPTION</p>

<!-- spontaneous:previewedit:start:box id:#{@page.images.schema_id} -->
<!-- spontaneous:previewedit:end:box id:#{@page.images.schema_id} -->

        HTML
      end
    end
    context "Request rendering" do
      setup do
        Spontaneous::Render.renderer_class = Spontaneous::Render::PreviewRenderer
        PreviewRender.layout :params
      end

      should "pass on passed params" do
        result = @page.render({
          :welcome => "hello"
        })
        result.should == "PAGE hello\n"
      end
    end


    context "entry parameters" do
      setup do
        Spontaneous::Render.renderer_class = Spontaneous::Render::PublishingRenderer
        PreviewRender.layout :entries
        @first = PreviewRender.new(:title => "first")
        @second = PreviewRender.new(:title => "second")
        @third = PreviewRender.new(:title => "third")
        @page.images << @first
        @page.images << @second
        @page.images << @third
        @page.save
      end
      should "be available to templates" do
        @page.render.should == "0>first\n1second\n2<third\n0:first\n1:second\n2:third\nfirst.second.third\n"
      end
    end

    context "Published rendering" do
      setup do
        @file = ::File.expand_path("../../fixtures/templates/direct.html.cut", __FILE__)
        @root = ::File.expand_path("../../fixtures/templates/", __FILE__)
        File.exists?(@file).should be_true
      end
      should "Use file directly if it exists" do
        result = Spontaneous.template_engine.request_renderer.new(@root).render_file(@file, nil)
        result.should == "correct\n"
      end
    end

    context "variables in templates" do
      setup do
        Spontaneous::Render.renderer_class = Spontaneous::Render::PublishingRenderer
        PreviewRender.layout :variables
        PreviewRender.style :variables

        @page.layout = :variables
        @first = PreviewRender.new(:title => "first")
        @page.images << @first
        @page.images.first.style = :variables
      end

      should "be passed to page content" do
        @page.render(:html, :param => "param").should == "param\n<variable/param/>\n\nlocal\n"
      end
    end
  end

end

