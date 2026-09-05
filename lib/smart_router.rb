# frozen_string_literal: true

require_relative 'smart_router/provider'
require_relative 'smart_router/operation'
require_relative 'smart_router/hard_constraints'
require_relative 'smart_router/scoring_engine'
require_relative 'smart_router/simulation_engine'
require_relative 'smart_router/analytics_reporter'
require_relative 'smart_router/router'

module SmartRouter
  VERSION = '1.0.0'
end
