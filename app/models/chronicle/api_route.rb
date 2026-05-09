module Chronicle
  class ApiRoute < ApplicationRecord
    validates :path, :http_method, presence: true
  end
end
