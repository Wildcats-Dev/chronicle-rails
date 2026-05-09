class User < ApplicationRecord
  def basic_info
    { 'id' => id, 'name' => name, 'email' => email }
  end
end
