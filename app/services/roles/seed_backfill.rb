module Roles
  # Adds privileges that `Role::DEFAULT_ROLES` has gained to roles already in the database.
  #
  # `Role.seed_defaults!` only fills in roles it is creating — an existing role is never
  # touched, so an administrator's edits are never overwritten. That is the right default,
  # but it means a fix to a shipped role never reaches an install that already has it: the
  # database keeps a "Front desk" that cannot open the invitation list because the seed
  # gained `invitations.view` after that row was written.
  #
  # This only ever adds. It will not remove a privilege an administrator took off a role,
  # rename anything, or create roles that are not already there — a missing role is
  # `seed_defaults!`'s job.
  class SeedBackfill
    Result = Struct.new(:role_name, :added_keys)

    def initialize(dry_run: false)
      @dry_run = dry_run
    end

    # => [Result], one per role that gained something. Roles already complete are omitted.
    def call
      Role::DEFAULT_ROLES.filter_map { |seed| backfill(seed) }
    end

    private

    def backfill(seed)
      role = Role.find_by(name: seed[:name])
      return if role.nil?

      missing = seed[:privileges] - role.privilege_keys
      return if missing.empty?

      # Only keys the catalog actually defines; a seed naming a removed privilege should
      # not resurrect it.
      privileges = Privilege.where(key: missing).to_a
      return if privileges.empty?

      role.privileges += privileges unless @dry_run
      Result.new(role.name, privileges.map(&:key).sort)
    end
  end
end
