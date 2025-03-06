class DebatesController  < ApplicationController

  before_action :check_admin, only: :new

  private
  
    def check_admin
      if !current_user.administrator?
        redirect_to debates_path
      end
    end

end

load Rails.root.join("app", "controllers", "debates_controller.rb")