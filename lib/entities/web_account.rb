module Intrigue
module Entity
class WebAccount < Intrigue::Model::Entity

  def self.metadata
    {
      :name => "WebAccount",
      :description => "A login username identified for a specific website"
    }
  end

  def validate_entity
    name =~ /^\w.*$/ &&
    details["domain"] =~ /^.*$/ &&
    details["uri"] =~ /^http.*$/
  end

end
end
end
