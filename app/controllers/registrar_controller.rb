class RegistrarController < ApplicationController
  before_action :authenticate_user!
  layout 'registrar/application'
end
