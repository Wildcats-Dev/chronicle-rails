module Chronicle
  class AdminUser < ApplicationRecord
    enum :role, a1: 0, a2: 1
    validates :password, presence: true, length: { minimum: 6 }
    validates :email, :auth_token, :name, presence: true

    has_secure_password validations: false

    A1 = :a1
    A2 = :a2

    def basic_info
      self.slice(:id, :name, :email)
    end
  end
end
