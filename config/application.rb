require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "sprockets/railtie"
require "rails/test_unit/railtie"
require 'shopify_api'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TvsQbSh
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0
    # ShopifyAPI::Context.setup(
    #   api_key: "7b478449b797b13c7ba36d839570a29c",
    #   api_secret_key: "00bee6606fb928607354050e592e1d12",
    #   host_name: "sdinland10",
    #   scope: "read_orders, read_products, write_orders, write_products",
    #   session_storage: ShopifyAPI::Auth::FileSessionStorage.new, # See more details below
    #   is_embedded: true, # Set to true if you are building an embedded app
    #   is_private: false, # Set to true if you are building a private app
    #   api_version: "2022-04" # The version of the API you would like to use
    # )
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
  end
end
