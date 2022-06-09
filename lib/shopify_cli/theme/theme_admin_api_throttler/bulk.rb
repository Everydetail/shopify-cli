# frozen_string_literal: true

require_relative "errors"
require_relative "bulk_job"
require "shopify_cli/thread_pool"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class Bulk
        MAX_BULK_SIZE = 10_485_760 # 10 MB
        MAX_BULK_FILES = 10 # files

        attr_accessor :admin_api

        def initialize(admin_api)
          @admin_api = admin_api
          @thread_pool = ShopifyCLI::ThreadPool.new(pool_size: 1)
          @latest_enqueued_request = nil
          @latest_enqueued_at = Time.now.to_f

          @mut = Mutex.new
          @job = BulkJob.new(self)
          @thread_pool.schedule(@job)

          @requests = []
          @requests_size = 0
        end

        def enqueue(request, &block)
          @mut.synchronize {
            @requests << request
            @requests_size += request[:body]["asset"]["size"]
            @latest_enqueued_request = block
            puts "Current Batch # of Files: #{@requests.size}, Current Batch Size (Bytes): #{@requests_size}"
          }
        end

        def shutdown
          @thread_pool.shutdown
        end

        def ready?
          # false if @requests.empty?
          @requests.size >= MAX_BULK_FILES
        end

        def consume_requests
          to_batch = []
          @mut.synchronize {
            # nlogn
            sorted = @requests.sort { |r1, r2| r1[:body]["asset"]["size"] <=> r2[:body]["asset"]["size"] }
            cutoff = 0
            batch_size = 0
            # n
            sorted.each.with_index do |r, idx|
              size = r[:body]["asset"]["size"]
              if idx >= MAX_BULK_FILES || batch_size + size > MAX_BULK_SIZE
                cutoff = idx
                break
              end
              to_batch << r
              batch_size += size
            end
            # n
            puts "Before Slice: #{@requests.size}"
            @requests.slice!(0, cutoff)
            puts "After Slice: #{@requests.size}"
          }
          return to_batch
        end

        def call_block(status, body, bulk_response)
          @mut.synchronize {
            @latest_enqueued_request&.call(status, body, bulk_response)
          }
        end

        private

        def wait
          sleep(0.1)
        end
      end
    end
  end
end
