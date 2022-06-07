# frozen_string_literal: true

require "shopify_cli/thread_pool/job"
require_relative "request_parser"
require_relative "response_parser"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class BatchRequest < ShopifyCLI::ThreadPool::Job
        MAX_BATCH_FILES = 3 # files
        MAX_BATCH_SIZE = 10_485_760 # 10MB
        BATCH_TIMEOUT = 0.2 # 200ms

        attr_accessor :size, :reqs

        def initialize(size:, reqs:, admin_api:, &block)
          @size = size
          @reqs = reqs
          @admin_api = admin_api
          @block = block
        end

        def perform!
          grouped_request = RequestParser.new(@reqs).parse

          status, body, response = @admin_api.rest_request(**grouped_request)
          resp_parser = ResponseParser.new(body)
          resp_parser.parse.each do |req|
            block.call(status, req, response)
          end
        rescue Exception => e # for debugging right now
          puts "error: #{e}"
        end
      end
    end
  end
end
