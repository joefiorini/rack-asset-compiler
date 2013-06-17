require 'rack/asset_compiler'
require 'rack/lobster'
require "rack/test"

include Rack::Test::Methods

describe "AssetCompiler" do
  before do
    @compiler = lambda do |source_file|
      @source_file = source_file
      'chickenscript'
    end

    @source_dir = File.join(File.dirname(__FILE__), 'fixtures/eggscripts')

    @options = {
      :url => '/chickenscripts/',
      :source_dir => @source_dir,
      :source_extension => 'eggscript',
      :content_type => 'text/chicken-script',
      :compiler => @compiler
    }
  end

  def app
    options = @options
    Rack::Builder.new {
      use Rack::Lint
      use Rack::AssetCompiler, options
      run Rack::Lobster.new
    }
  end

  it "no longer raises an error if content_type is missing" do
    lambda {
      @options.delete(:content_type)
      get '/oops'
    }.should_not raise_error
  end

  it "uses registered mime type for extension as default content type" do
    @options.delete(:content_type)
    @options.delete(:source_extension)
    get '/chickenscripts/blah.png'
    last_response.content_type.should == Rack::Mime.mime_type('.png')
  end

  it "should match files directly beneath the URL" do
    get '/chickenscripts/application.chickenscript'
    @source_file.should == "#{@source_dir}/application.eggscript"
    last_response.body.should == 'chickenscript'
  end

  it "should match files underneath a subdirectry" do
    get '/chickenscripts/subdir/application.chickenscript'
    @source_file.should == "#{@source_dir}/subdir/application.eggscript"
    last_response.body.should == 'chickenscript'
  end

  it "should return a 403 error when a directory is requested" do
    get '/chickenscripts/'
    last_response.status.should == 403
  end

  it "should not call the compiler for missing files" do
    get '/chickenscripts/missing.chickenscript'
    @source_file.should be_nil
  end

  it "should use the correct content-type" do
    get '/chickenscripts/application.chickenscript'
    last_response.content_type.should == 'text/chicken-script'
  end

  it "should not match files outside the URL parameter" do
    get '/lobster'
    last_response.body.should include('Lobstericious')
  end

  it "should include a last-modified header" do
    get '/chickenscripts/application.chickenscript'
    last_response.headers["Last-Modified"].should == File.mtime("#{@source_dir}/application.eggscript").httpdate
  end

  it "should respond with a 304 on a last-modified hit" do
    last_modified_time = File.mtime("#{@source_dir}/application.eggscript").httpdate
    get '/chickenscripts/application.chickenscript', {}, {'HTTP_IF_MODIFIED_SINCE' => last_modified_time}
    last_response.status.should == 304
    last_response.body.should == "Not modified\r\n"
  end

  it "should return the compiled code on a last-modified miss" do
    last_modified_time = (File.mtime("#{@source_dir}/application.eggscript") - 10).httpdate
    get '/chickenscripts/application.chickenscript', {}, {'HTTP_IF_MODIFIED_SINCE' => last_modified_time}
    last_response.status.should == 200
    last_response.body.should == "chickenscript"
  end

  it "should reject requests with a .." do
    get '/chickenscript/../somethingbad'
    last_response.status.should == 403
  end

  describe "Caching" do
    it "should not cache by default" do
      @options.delete(:cache)
      get '/chickenscripts/application.chickenscript'
      last_response.headers.should_not include('Cache-Control')
    end

    it "should cache by default on production" do
      @options.delete(:cache)
      old_rack_env = ENV['RACK_ENV']
      ENV['RACK_ENV'] = 'production'
      get '/chickenscripts/application.chickenscript'
      ENV['RACK_ENV'] = old_rack_env

      last_response.headers.should include('Cache-Control')
    end

    it "should set not the cache header when the cache options is false" do
      @options[:cache] = false
      get '/chickenscripts/application.chickenscript'
      last_response.headers.should_not include('Cache-Control')
      last_response.headers.should_not include('Expires')
    end

    it "should set the cache header to a duration of one week when the cache options is true" do
      @options[:cache] = true
      get '/chickenscripts/application.chickenscript'
      last_response.headers['Cache-Control'].should == "public,max-age=604800"
      last_response.headers.should include('Expires')
    end
  end
end
