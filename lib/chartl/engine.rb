module Chartl
  class Engine < Rails::Engine
    engine_name 'chartl'

    config.autoload_paths += %W(#{config.root}/lib)

    # use rspec for tests
    config.generators do |g|

    end
  end
end
