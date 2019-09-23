class Calendarupdate < ApplicationRecord
  has_many :lessons

  validates :capacity, presence: true, numericality: { greater_than: 0 }
  validates :name, presence: true
  validates :description, presence: true
  validates :location, presence: true
  validates :moment, presence: true
  validates_length_of :moment, minimum: 5, message: "Sélectionner au moins une durée"

  monetize :full_price_cents
  monetize :half_price_cents

  def self.format_stages_ref(stages)
    stages.pluck(:period_start, :name, :id)
    .map { |array| "#{array[0].strftime("%d/%m/%Y")} - #{array[1]}" }
  end

  def self.formatted_moments(stages)
    split_stages = stages.pluck(:moment, :full_price_cents, :half_price_cents)

    split_stages.map do |mix|
      mix[0] = mix[0].split("†").select { |m| m!= "" }
      mix[0].map { |m| m == "Journée" ? "#{m} - #{ (mix[1] / 100.0).round(2) } €" : "#{m} - #{ (mix[2] / 100.0).round(2) } €" }
    end
  end

end
