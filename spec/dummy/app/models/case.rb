class Case
  include ActiveModel::Model

  attr_accessor :name
  attr_accessor :state_machine
  validates_presence_of :name



end
