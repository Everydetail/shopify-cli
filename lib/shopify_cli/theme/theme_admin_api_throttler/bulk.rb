# frozen_string_literal: true

require_relative "errors"
require_relative "bulk_job"
require "shopify_cli/thread_pool"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      class Bulk
        KILOBYTE = 1_024
        MEGABYTE = KILOBYTE * 1_024
        MAX_BULK_BYTESIZE = MEGABYTE * 1 # (change to 5MB or 10MB) Spin limit seems to be 1MB
        MAX_BULK_FILES = 10 # files
        QUEUE_TIMEOUT = 0.2 # 200ms

        attr_accessor :admin_api

        def initialize(admin_api)
          @admin_api = admin_api
          @latest_enqueued_at = now

          pool_size = 1
          @thread_pool = ShopifyCLI::ThreadPool.new(pool_size: pool_size)

          pool_size.times do
            @thread_pool.schedule(
              BulkJob.new(self)
            )
          end

          @put_requests = []

          @mut = Mutex.new
        end

        def enqueue(put_request)
          @mut.synchronize do
            @latest_enqueued_at = now
            @put_requests << put_request
          end
        end

        def shutdown
          while !@put_requests.empty?
            sleep(0.2)
          end
          @thread_pool.shutdown
        end

        def consume_put_requests
          
          to_batch = []

          @mut.synchronize do
            is_ready = false
            while !is_ready
              request = @put_requests.shift

              to_batch_temp = [*to_batch, request]
              bulk_size = to_batch_temp.size
              bulk_bytesize = to_batch_temp.map(&:size).reduce(:+).to_f
              
              if bulk_size >= MAX_BULK_FILES || bulk_bytesize >= MAX_BULK_BYTESIZE
                is_ready = true
                request = @put_requests.unshift(request)
              else
                to_batch << request
              end
            end
          end
          
          puts "consume_put_requests ================="
          puts "size:     #{to_batch.size}"
          puts "bytesize: #{(to_batch.map(&:size).reduce(:+).to_f / 1000000).round(2)}MB"

          to_batch

          #
          # ---------------------------------
          # I've noticed order of assets is important, otherwise the backend
          # blocks the upload (e.g., when a file reference other that doesn't
          # exist)
          # ---------------------------------
          #
          # to_batch = []
          # @mut.synchronize do
          #   # nlogn
          #   sorted = @put_requests.sort { |r1, r2| r1.size <=> r2.size }
          #   cutoff = 0
          #   batch_size = 0
          #   # n
          #   sorted.each.with_index do |r, idx|
          #     size = r.size
          #     if idx >= MAX_BULK_FILES || batch_size + size > MAX_BULK_BYTESIZE
          #       cutoff = idx
          #       break
          #     end
          #     to_batch << r
          #     batch_size += size
          #   end
          #   # n
          #   # puts "Before Slice: #{bulk_size}"
          #   @put_requests.slice!(0, cutoff)
          #   # puts "After Slice: #{bulk_size}"

          #   if to_batch == @put_requests
          #     # FIXME: (last 4 files were never been taken)
          #     @put_requests.clear
          #   end
          # end
          
          # puts "consume_put_requests ================="
          # puts "size:     #{to_batch.size}"
          # puts "bytesize: #{(to_batch.map(&:size).reduce(:+).to_f / 1000000).round(2)}MB"

          to_batch
        end

        def ready?
          queue_timeout? || bulk_size >= MAX_BULK_FILES || bulk_bytesize >= MAX_BULK_BYTESIZE
        end

        def bulk_bytesize
          @put_requests.map(&:size).reduce(:+).to_i
        end

        private

        def bulk_size
          @put_requests.size
        end

        def queue_timeout?
          return false if bulk_size.zero?
          elapsed_time = now - @latest_enqueued_at
          elapsed_time > QUEUE_TIMEOUT
        end

        def now
          Time.now.to_f
        end
      end
    end
  end
end
