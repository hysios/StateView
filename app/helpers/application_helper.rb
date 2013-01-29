module ApplicationHelper

  def r(name, value)
    content_tag(:data, value,  :meta => name )
  end

  def rh(name, value)
    content_tag(:data, nil,  :meta => name, :value => value )
  end
end
