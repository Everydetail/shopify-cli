# frozen_string_literal: true

require "forwardable"

require_relative "theme_admin_api_throttler/bulk"
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
        @bulk = Bulk.new(@admin_api)
      end

      def put(path:, **args, &block)
        asset_size = JSON.parse(args[:body])["asset"]["size"]
        if active? && asset_size <= Bulk::MAX_BULK_SIZE # if bulking is active and valid
          bulk_request(method: "PUT", path: bulk_path(path), **args, &block)
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

      def bulk_request(method:, path:, **args, &block)
        request = format_request(method: method, path: path, **args)
        @bulk.enqueue(request, &block)
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
    end
  end
end
