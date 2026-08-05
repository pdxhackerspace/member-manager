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

  # Downloads every role, its privileges, and the topics it is attached to. Keyed by name and
  # privilege key rather than id so the file can be moved between instances.
  def export
    send_data Roles::DefinitionExport.new.to_json,
              filename: "role-definitions-#{Time.current.utc.strftime('%Y%m%d-%H%M%S')}.json",
              type: 'application/json',
              disposition: 'attachment'
  end

  def import
    @import_mode = Roles::DefinitionImport::DEFAULT_MODE
  end

  # Stays on the page whenever there is something to read — a preview, a skipped privilege, or
  # an error — and only redirects when the import applied cleanly with nothing to report.
  def run_import
    @import_mode = params[:mode].to_s
    @dry_run = params[:dry_run] == '1'
    @json_text = params[:json].to_s
    @result = Roles::DefinitionImport.call(import_document, mode: @import_mode, dry_run: @dry_run)

    return render :import, status: :unprocessable_content unless @result.success?
    return render :import if @dry_run || @result.warnings.any?

    redirect_to roles_path, notice: "Role definitions imported: #{@result.summary}."
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

  # An uploaded file wins over the paste box so a stale textarea cannot shadow the file the
  # admin just chose.
  def import_document
    upload = params[:file]
    return upload.read if upload.respond_to?(:read)

    @json_text
  end
end
