class AddColumnsToLessons < ActiveRecord::Migration[5.2]
  def change
    add_column :calendarupdates, :name, :string
    add_column :calendarupdates, :description, :text
    add_column :calendarupdates, :location, :string
    add_column :calendarupdates, :full_price_cents, :integer
    add_column :calendarupdates, :half_price_cents, :integer
    add_column :calendarupdates, :capacity, :integer
    add_column :calendarupdates, :capacity_am, :integer
    add_column :calendarupdates, :capacity_pm, :integer
    add_column :calendarupdates, :moment, :string
    add_column :calendarupdates, :available, :boolean

    add_reference :lessons, :calendarupdate, foreign_key: true
    remove_reference :calendarupdates, :lesson
  end
end
