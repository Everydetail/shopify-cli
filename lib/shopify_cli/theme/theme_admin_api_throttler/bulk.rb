# frozen_string_literal: true

require_relative "errors"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class Bulk
        def initialize(admin_api)
          @admin_api = admin_api
          @thread_pool = ShopifyCLI::ThreadPool.new(pool_size: 1)
          # @latest_enqueued_request =
          # @latest_enqueued_at = 
        end

        def enqueue(request)
          # use mutex in this method {
          @thread_pool.schedule(request)
          # }
        end

        def wait_request(request)
          retries = 10

          until request.done?
            retries -= 1
            wait
          end

          raise Errors::TimeoutError unless request.done?
        end

        def shutdown
          @thread_pool.shutdown
        end

        def ready?
          # if @latest_enqueued_at greater than 200ms then true else false
        end

        def consume_requests
          # use mutex here {
          #   requests = @list_of_requests
          #   clean the list of requests
          #   return the @list_of_requests
          # }

        def call_block(status, body, bulk_response)\
          # use mutex here {
          #   request.block.call(status, body, bulk_response)
          # }
        end

        private

        def wait
          sleep(0.1)
        end
      end
    end
  end
end
