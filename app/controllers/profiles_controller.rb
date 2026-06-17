class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
    render layout: false if turbo_frame_request?
  end

  def update
    @user = current_user
    attrs = profile_params.to_h

    if attrs[:password].blank? && attrs[:password_confirmation].blank?
      attrs.delete(:password)
      attrs.delete(:password_confirmation)
    end

    if @user.update(attrs)
      bypass_sign_in(@user) if attrs.key?(:password)
      redirect_to root_path, notice: "Profilo aggiornato."
    else
      render :edit, layout: false, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.fetch(:user, {}).permit(:name, :lastname, :email, :password, :password_confirmation)
  end
end
