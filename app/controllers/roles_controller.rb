# Configures reusable privilege bundles. Editing a role changes what every topic carrying it
# confers, so this stays admin-only: it is privilege administration, not topic management.
class RolesController < AdminController
  before_action :set_role, only: %i[edit update destroy]

  def index
    @roles = Role.ordered.includes(:privileges, topic_roles: :training_topic)
  end

  def new
    @role = Role.new
    load_privilege_catalog
  end

  def edit
    load_privilege_catalog
  end

  def create
    @role = Role.new(role_params)

    if @role.save
      redirect_to roles_path, notice: "Role '#{@role.name}' created."
    else
      load_privilege_catalog
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @role.update(role_params)
      redirect_to roles_path, notice: "Role '#{@role.name}' updated."
    else
      load_privilege_catalog
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    attached = @role.topic_roles.count

    if attached.positive?
      redirect_to roles_path,
                  alert: "Cannot delete '#{@role.name}' while it is attached to #{attached} topic(s)."
    else
      @role.destroy
      redirect_to roles_path, notice: 'Role deleted.'
    end
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def load_privilege_catalog
    @privileges_by_category = Privilege.ordered.group_by { |privilege| privilege.category.presence || 'Other' }
  end

  def role_params
    params.expect(role: [:name, :description, { privilege_ids: [] }])
  end
end
