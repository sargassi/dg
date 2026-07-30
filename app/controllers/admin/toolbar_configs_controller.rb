module Admin
  class ToolbarConfigsController < ApplicationController
    before_action :require_godlike!

    def index
      all_paths = []
      @sections = ToolbarConfig::SECTIONS.map do |key, info|
        builtins = helpers.send(info[:controller], skip_config: true)
        custom = ToolbarConfig.where(section: key).custom.order(:position)
        items = builtins.map do |item|
          config = ToolbarConfig.find_or_create_by!(section: key, item_label: item[:label]) { |c| c.visible = true }
          all_paths << item[:path]
          item.merge(visible: config.visible, config_id: config.id, custom: false)
        end
        items += custom.map do |c|
          all_paths << c.path
          { label: c.item_label, icon: c.icon, path: c.path, visible: c.visible,
            config_id: c.id, group: :custom, type: :nav, custom: true }
        end
        { key: key, label: info[:label], items: items }
      end
      @suggested_paths = all_paths.uniq.sort
      @new_config = ToolbarConfig.new
    end

    def create
      @config = ToolbarConfig.new(menu_item_params)
      @config.visible = true
      if @config.save
        redirect_to admin_toolbar_configs_path, notice: "Voce aggiunta."
      else
        redirect_to admin_toolbar_configs_path, alert: @config.errors.full_messages.join(", ")
      end
    end

    def update
      @config = ToolbarConfig.find(params[:id])
      @config.update!(visible: params[:visible])
      redirect_to admin_toolbar_configs_path, notice: "Aggiornato."
    end

    def destroy
      @config = ToolbarConfig.find(params[:id])
      @config.destroy
      redirect_to admin_toolbar_configs_path, notice: "Voce rimossa."
    end

    private

    def menu_item_params
      params.require(:toolbar_config).permit(:section, :item_label, :path, :icon, :position)
    end
  end
end
