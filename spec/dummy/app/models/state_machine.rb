class StateMachine
  include ActiveModel::Model

  attr_accessor :object
  attr_accessor :state
  validates_presence_of :object

end
