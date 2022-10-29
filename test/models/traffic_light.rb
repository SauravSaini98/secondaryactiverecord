# frozen_string_literal: true

class TrafficLight < SecondaryActiveRecord::Base
  serialize :state, Array
  serialize :long_state, Array
end
