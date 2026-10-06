class AddVacanciesSeenAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :vacancies_seen_at, :datetime,
               comment: "When the user last opened the vacancy feed; vacancies created after this count as new"
  end
end
