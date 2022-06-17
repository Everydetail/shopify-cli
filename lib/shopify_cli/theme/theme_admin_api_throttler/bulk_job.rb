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

          # Mutex used to coordinate changes performed by the bulk item block
          @block_mutex = Mutex.new
        end

        def perform!
          return unless bulk.ready?
          put_requests = bulk.consume_put_requests
          bulk_status, bulk_body, response = rest_request(put_requests)

          if bulk_status == 207
            responses(bulk_body).each_with_index do |tuple, index|
              status, body = tuple
              put_request = put_requests[index]
              if status == 200
                @block_mutex.synchronize do
                  put_request.block.call(status, body, response)
                end
              else
                @block_mutex.synchronize do
                  err = ShopifyCLI::API::APIRequestError.new(response: { body: body })
                  put_request.block.call(status, err, nil)
                end
              end
            end
          else
            puts "status: #{bulk_status}"
            handle_requeue
          end
        end

        private

        def rest_request(put_requests)
          request = RequestParser.new(put_requests).parse
          bulk.admin_api.rest_request(**request)
        end

        def responses(response_body)
          ResponseParser.new(response_body).parse
        end

        def handle_requeue
          # handles the retrying of the request
        end
      end
    end
  end
end
