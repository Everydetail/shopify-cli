# frozen_string_literal: true

require "shopify_cli/thread_pool/job"
require_relative "request_parser"
require_relative "response_parser"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class BulkJob < ShopifyCLI::ThreadPool::Job
        JOB_TIMEOUT = 0.2 # 200ms

        attr_reader :bulk

        def initialize(bulk)
          super(JOB_TIMEOUT)
          @bulk = bulk
        end

        def perform!
          return unless bulk.ready?

          bulk_status, bulk_body, bulk_response = @admin_api.rest_request(**bulk_request)

          responses(bulk_response).each do |tuple|
            status, body = tuple
            
            bulk.call_block(status, body, bulk_response)
          end
        end

        private

        def responses(bulk_response)
          ResponseParser.new(body).parse
        end

        def bulk_request
          requests = bulk.consume_requests
          RequestParser.new(requests).parse
        end
      end
    end
  end
end
