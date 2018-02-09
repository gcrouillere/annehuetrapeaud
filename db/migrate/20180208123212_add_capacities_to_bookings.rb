class AddCapacitiesToBookings < ActiveRecord::Migration[5.0]
  def change
    add_column :bookings, :capacity_am, :integer
    add_column :bookings, :capacity_pm, :integer
    add_column :lessons, :moment, :string
  end
end
