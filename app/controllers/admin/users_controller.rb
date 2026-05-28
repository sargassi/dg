module Admin
  class UsersController < ApplicationController
    before_action :require_godlike!

    def index
      @users = User.includes(:user_roles, :abilities).order(:user_type, :email)
      @operator  = User.new(user_type: 'company_operator')
      @customer  = User.new(user_type: 'customer')
      @supplier  = User.new(user_type: 'supplier')
    end

    def new
      redirect_to admin_users_path
    end

    def create
      @user = User.new(user_params)
      if @user.save
        redirect_to admin_users_path, notice: "Utente creato."
      else
        @users = User.includes(:user_roles, :abilities).order(:user_type, :email)
        @operator  = @user.user_type == 'company_operator' ? @user : User.new(user_type: 'company_operator')
        @customer  = @user.user_type == 'customer' ? @user : User.new(user_type: 'customer')
        @supplier  = @user.user_type == 'supplier' ? @user : User.new(user_type: 'supplier')
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      @user = User.find(params[:id])
      @all_abilities = Ability.includes(:user_abilities).order(:category, :name)
    end

    def update
      @user = User.find(params[:id])
      attrs = user_params.to_h
      attrs['godlike'] = ActiveModel::Type::Boolean.new.cast(attrs['godlike']) if attrs.key?('godlike')
      attrs['enabled'] = ActiveModel::Type::Boolean.new.cast(attrs['enabled']) if attrs.key?('enabled')
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

        redirect_to params[:return_to].presence || admin_users_path, notice: "Utente aggiornato."
      else
        @all_abilities = Ability.includes(:user_abilities).order(:category, :name)
        if params[:return_to].present?
          render "directory/edit", layout: false, status: :unprocessable_entity
        else
          render :edit, status: :unprocessable_entity
        end
      end
    end

    def abilities
      @user = User.find(params[:id])
      @all_abilities = Ability.includes(:user_abilities).order(:category, :name)
      render layout: false
    end

    def destroy
      @user = User.find(params[:id])
      if @user == current_user
        redirect_to admin_users_path, alert: "Non puoi eliminare te stesso."
      else
        @user.destroy
        redirect_to admin_users_path, notice: "Utente eliminato."
      end
    end

    private

    def user_params
      params.fetch(:user, {}).permit(:name, :lastname, :email, :user_type, :godlike, :password, :password_confirmation, :date_of_birth, :date_of_hiring, :enabled, :fiscal_code, :vat)
    end
  end
end
