class Product < ActiveRecord::Base
  attr_accessible :title, :price

  validates :title, :presence => true
end
