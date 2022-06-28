require 'byebug'

module Extension
  module Features
    class ArgoRuntime
      RUNTIMES = [
        Runtimes::Admin.new,
        Runtimes::CheckoutPostPurchase.new,
        Runtimes::CheckoutUiExtension.new,
        # Runtimes::ThemeAppExtension.new,
      ]

      def self.find(cli_package:, identifier:)
        # byebug
        RUNTIMES.find { |runtime| runtime.active_runtime?(cli_package, identifier) }
      end
    end
  end
end
