require 'sinatra/base'

module Sinatra
  module Test
    include Rack::Utils

    attr_reader :app, :request, :response

    def self.deprecate(framework)
      warn <<-EOF
Warning: support for the #{framework} testing framework is deprecated and
will be dropped in Sinatra 1.0. See <http://sinatra.github.com/testing.html>
for more information.
      EOF
    end

    def make_request(verb, path, data={}, h=nil)
      @app = Sinatra::Application if @app.nil? && defined?(Sinatra::Application)
      fail "@app not set - cannot make request" if @app.nil?

      @request = Rack::MockRequest.new(@app)
      options  = { :lint => true }

      session = data[:session]
      session = data[:env][:session] if data[:env]
      options['rack.session'] = session unless session.nil?

      case data
      when Hash
        if env = data.delete(:env)
          options = rack_options(env)
        end
        options.merge!(h) if h.is_a?(Hash)
        options[:input] = param_string(data)
      when String
        options = rack_options(h) if h.is_a?(Hash)
        options[:input] = data
      end

      yield @request if block_given?
      @response = @request.request(verb, path, options)
    end

    def get(path, *args, &b)  ; make_request('GET', path, *args, &b) ; end
    def head(path, *args, &b) ; make_request('HEAD', path, *args, &b) ; end
    def post(path, *args, &b) ; make_request('POST', path, *args, &b) ; end
    def put(path, *args, &b)  ; make_request('PUT', path, *args, &b) ; end
    def delete(path, *args, &b) ; make_request('DELETE', path, *args, &b) ; end

    def follow!
      make_request 'GET', @response.location
    end

    def body ; @response.body ; end
    def status ; @response.status ; end

    # Delegate other missing methods to @response.
    def method_missing(name, *args, &block)
      if @response && @response.respond_to?(name)
        @response.send(name, *args, &block)
      else
        super
      end
    end

    # Also check @response since we delegate there.
    def respond_to?(symbol, include_private=false)
      super || (@response && @response.respond_to?(symbol, include_private))
    end

  private

    RACK_OPTIONS = {
      :accept       => 'HTTP_ACCEPT',
      :agent        => 'HTTP_USER_AGENT',
      :host         => 'HTTP_HOST',
      :session      => 'HTTP_COOKIE',
      :cookies      => 'HTTP_COOKIE',
      :content_type => 'CONTENT_TYPE'
    }

    def rack_options(opts)
      opts.merge(:lint => true).inject({}) do |hash,(key,val)|
        key = RACK_OPTIONS[key] || key
        hash[key] = val
        hash
      end
    end

    def param_string(value, prefix = nil)
      case value
      when Array
        value.map { |v|
          param_string(v, "#{prefix}[]")
        } * "&"
      when Hash
        value.map { |k, v|
          param_string(v, prefix ? "#{prefix}[#{escape(k)}]" : escape(k))
        } * "&"
      else
        "#{prefix}=#{escape(value)}"
      end
    end

    if defined? Sinatra::Compat
      # Deprecated. Use: "get" instead of "get_it".
      %w(get head post put delete).each do |verb|
        eval <<-RUBY, binding, __FILE__, __LINE__
        def #{verb}_it(*args, &block)
          sinatra_warn "The #{verb}_it method is deprecated; use #{verb} instead."
          make_request('#{verb.upcase}', *args, &block)
        end
        RUBY
      end
    end
  end

  class TestHarness
    include Test

    def initialize(app=nil)
      @app = app || Sinatra::Application
    end
  end
end
