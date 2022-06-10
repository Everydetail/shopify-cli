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
              if status == 200
                put_request = put_requests[index]

                @block_mutex.synchronize do
                  put_request.block.call(status, body, response)
                end
              else
                # TOOD: handle errors
                puts "[BulkJob] assest upload error =>"
                p status
                # p body
              end
            end
          else
            # TODO: handle errors
            puts "[BulkJob] bulk request error =>"
            p bulk_status
          end
  
        rescue => e
          puts "[BulkJob] error =>"
          p e
        end

        private

        def rest_request(put_requests)
          request = RequestParser.new(put_requests).parse
          bulk.admin_api.rest_request(**request)
        end

        def responses(response_body)
          ResponseParser.new(response_body).parse
        end
      end
    end
  end
end
