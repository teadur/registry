class User < ActiveRecord::Base
  include Versions # version/user_version.rb
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :trackable, :timeoutable
  # TODO: Foreign user will get email with activation link,email,temp-password.
  # After activisation, system should require to change temp password.
  # TODO: Estonian id validation

  validates :username, :password, presence: true
  validates :identity_code, uniqueness: true, allow_blank: true
  validates :identity_code, presence: true, if: -> { country.iso == 'EE' }
  validates :email, presence: true, if: -> { country.iso != 'EE' }

  validate :validate_identity_code

  ROLES = %w(user customer_service admin)

  def to_s
    username
  end

  def country
    Country.new(country_code)
  end

  private

  def validate_identity_code
    return unless identity_code.present?
    code = Isikukood.new(identity_code)
    errors.add(:identity_code, :invalid) unless code.valid?
  end
end
