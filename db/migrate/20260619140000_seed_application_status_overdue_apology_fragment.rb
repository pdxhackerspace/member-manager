class SeedApplicationStatusOverdueApologyFragment < ActiveRecord::Migration[8.1]
  def up
    TextFragment.ensure_exists!(
      key: 'application_status_overdue_apology',
      title: 'Application Status: Overdue Apology',
      content: <<~HTML
        <p>
          We're sorry your application is taking longer than usual. PDX Hackerspace is run entirely
          by volunteers, and sometimes review can take longer than we'd like. Thank you for your patience
          while our team catches up.
        </p>
      HTML
    )
  end

  def down
    TextFragment.find_by(key: 'application_status_overdue_apology')&.destroy
  end
end
