class DirectoryController < ApplicationController
  include Pagy::Backend

  def index
    @users = User.all

    if params[:q].present?
      q = "%#{params[:q]}%"
      @users = @users.where(
        "name LIKE :q OR lastname LIKE :q OR email LIKE :q OR fiscal_code LIKE :q OR vat LIKE :q",
        q: q
      )
    end

    @pagy, @users = pagy(@users, items: 12)
  end

  def show
    @user = User.find(params[:id])
    render layout: false
  end

  def edit
    @user = User.find(params[:id])
    @all_abilities = Ability.includes(:user_abilities).order(:category, :name)
    render layout: false
  end

  def update
    @user = User.find(params[:id])
    attrs = user_params.to_h
    attrs['godlike'] = ActiveModel::Type::Boolean.new.cast(attrs['godlike'])
    attrs['enabled'] = ActiveModel::Type::Boolean.new.cast(attrs['enabled'])
    if @user.update(attrs)
      if params[:roles].present?
        @user.user_roles.destroy_all
        params[:roles].each do |role|
          @user.user_roles.find_or_create_by!(role: role)
        end
      end

      if params[:ability_ids].present?
        existing_ids = @user.ability_ids.to_set
        submitted_ids = params[:ability_ids].map(&:to_i).to_set

        (submitted_ids - existing_ids).each do |ability_id|
          ability = Ability.find(ability_id)
          @user.grant_ability(ability, granted_by: current_user)
        end

        (existing_ids - submitted_ids).each do |ability_id|
          ability = Ability.find(ability_id)
          @user.revoke_ability(ability)
        end
      end

      redirect_to directory_path(q: params[:q]), notice: "Utente aggiornato."
    else
      redirect_to edit_directory_user_path(@user, q: params[:q]), alert: @user.errors.full_messages.join(", ")
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :lastname, :email, :user_type, :godlike, :password, :password_confirmation, :date_of_birth, :date_of_hiring, :enabled, :fiscal_code, :vat)
  end
end
