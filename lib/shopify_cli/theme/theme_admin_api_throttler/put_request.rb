# frozen_string_literal: true

require "shopify_cli/thread_pool/job"
require_relative "request_parser"
require_relative "response_parser"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class PutRequest
        attr_reader :method, :body, :path, :block

        def initialize(path, body, &block)
          @method = "PUT"
          @path = path
          @body = body
          @block = block
        end

        def to_h
          {
            method: method,
            path: path,
            body: body,
          }
        end

        def bulk_path
          path.gsub(/.json$/, "/bulk.json")
        end

        def size
          body.bytesize
        end
      end
    end
  end
end
