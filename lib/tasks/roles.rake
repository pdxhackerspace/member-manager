namespace :roles do
  desc 'Write role definitions as JSON to stdout or ROLES_FILE'
  task export: :environment do
    json = Roles::DefinitionExport.new.to_json
    path = ENV.fetch('ROLES_FILE', nil)

    if path.present?
      File.write(path, "#{json}\n")
      puts "Wrote #{Role.count} role(s) to #{path}"
    else
      puts json
    end
  end

  desc 'Apply a role definitions JSON file (ROLES_FILE=path [MODE=merge|replace] [DRY_RUN=1])'
  task import: :environment do
    path = ENV.fetch('ROLES_FILE', nil)

    if path.blank?
      puts 'ERROR: ROLES_FILE environment variable is required'
      puts 'Usage: ROLES_FILE=db/role_definitions/director_roles.json MODE=replace rails roles:import'
      exit 1
    end

    unless File.exist?(path)
      puts "ERROR: File does not exist: #{path}"
      exit 1
    end

    dry_run = ENV['DRY_RUN'] == '1'
    result = Roles::DefinitionImport.call(File.read(path),
                                          mode: ENV.fetch('MODE', Roles::DefinitionImport::DEFAULT_MODE),
                                          dry_run: dry_run)

    result.warnings.each { |message| puts "WARNING: #{message}" }

    unless result.success?
      result.errors.each { |message| puts "ERROR: #{message}" }
      puts 'Nothing was saved.'
      exit 1
    end

    puts "#{dry_run ? 'Would apply' : 'Applied'}: #{result.summary}"
  end

  desc 'Add privileges the shipped roles have gained to roles already in the database ' \
       '(DRY_RUN=1 to preview)'
  task backfill_seeds: :environment do
    dry_run = ENV['DRY_RUN'].present?
    results = Roles::SeedBackfill.new(dry_run: dry_run).call

    if results.empty?
      puts 'Every shipped role already has the privileges it ships with. Nothing to do.'
      next
    end

    results.each do |result|
      puts "#{dry_run ? 'Would add to' : 'Added to'} #{result.role_name}: #{result.added_keys.join(', ')}"
    end
    puts
    puts "#{results.sum { |r| r.added_keys.size }} privilege(s) across #{results.size} role(s)."
    puts 'Run without DRY_RUN=1 to apply.' if dry_run
  end
end
