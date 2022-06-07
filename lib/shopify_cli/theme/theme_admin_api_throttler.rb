# frozen_string_literal: true

require "forwardable"

require_relative "theme_admin_api_throttler/batch"
require_relative "theme_admin_api_throttler/batch_request"
require_relative "theme_admin_api_throttler/errors"

module ShopifyCLI
  module Theme
    class ThemeAdminAPIThrottler
      extend Forwardable

      def_delegators :@admin_api, :get, :post, :delete, :rest_request

      def initialize(ctx, admin_api)
        @ctx = ctx
        @admin_api = admin_api
        @active = true
        @current_batch_size = 0
        @current_batch_reqs = []
        @batch = Batch.new(@admin_api)
      end

      def put(path:, **args, &block)
        asset_size = JSON.parse(args[:body])["asset"]["size"]
        if active? && asset_size <= BatchRequest::MAX_BATCH_SIZE # if batching is active and valid
          batch_request(method: "PUT", path: bulk_path(path), **args, &block)
        else
          rest_request(method: "PUT", path: path, **args, &block)
        end

      rescue Errors::TimeoutError
        @ctx.debug("throttling timeout: #{path} => #{args}")

        # performs the regular request as a fallback
        rest_request(method: "PUT", path: path, **args)
      end

      def activate!
        @active = true
      end

      def deactivate!
        @active = false
      end

      def active?
        @active
      end

      private

      def enqueue_batch(&block)
        puts "Current Batch: #{@current_batch_reqs.size} Files, #{@current_batch_size} Bytes"
        # grouped_request = RequestParser.new(@current_batch_reqs).parse
        # @current_batch_reqs = []
        # @current_batch_size = 0

        # status, body, response = @admin_api.rest_request(**grouped_request)
        # resp_parser = ResponseParser.new(body)
        # resp_parser.parse.each do |req|
        #   block.call(status, req, response)
        # end

        # Async Code
        batch_request = BatchRequest.new(size: @current_batch_size, reqs: @current_batch_reqs, admin_api: @admin_api, &block)
        @current_batch_size = 0
        @current_batch_reqs = []
        puts "#{Thread.current}"
        @batch.enqueue(batch_request)
      end

      def check_batch_ready(&block)
        if @current_batch_reqs.size == BatchRequest::MAX_BATCH_FILES || @current_batch_size == BatchRequest::MAX_BATCH_SIZE
          enqueue_batch(&block)
        else
          curr_size = @current_batch_size
          curr_num = @current_batch_reqs.size
          Thread.new do
            catch(:stop_thread) do
              sleep(BatchRequest::BATCH_TIMEOUT)
              return if @current_batch_reqs.empty?
              enqueue_batch(&block) if curr_num == @current_batch_reqs.size && curr_size == @current_batch_size
            end
          end
        end
      end

      def batch_request(method:, path:, **args, &block)
        request = format_request(method: method, path: path, **args)
        asset_size = request[:body]["asset"]["size"]
        puts "Processing file: #{request[:body]["asset"]["key"]}: #{asset_size} bytes"
        if @current_batch_reqs.size == BatchRequest::MAX_BATCH_FILES || @current_batch_size + asset_size > BatchRequest::MAX_BATCH_SIZE
          enqueue_batch(&block)
        end
        append_to_batch(request)
        check_batch_ready(&block)
      end

      def bulk_path(path)
        path.gsub(/.json$/, "/bulk.json")
      end

      def format_request(method:, path:, **args)
        {
          shop: @admin_api.shop,
          path: path,
          method: method,
          api_version: ThemeAdminAPI::API_VERSION, #TODO: need access to the API_VERSION
          body: args[:body].is_a?(Hash) ? args[:body] : JSON.parse(args[:body])
        }
      end

      def append_to_batch(request)
        @current_batch_reqs << request
        @current_batch_size += request[:body]["asset"]["size"]
      end
    end
  end
end
