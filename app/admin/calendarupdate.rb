ActiveAdmin.register Calendarupdate do
  permit_params :period_start, :period_end, :full_price_cents, :half_price_cents, :capacity, :name, :description, :location, moment: []
  actions  :index, :new, :create, :destroy, :show, :edit
  menu priority: 4
  config.filters = false

  form do |f|
    f.inputs "" do
      f.input :period_start, as: :datepicker
      f.input :full_price_cents, :hint => "Prix en centimes d'euros. Ex: entrez 1200 pour un prix de 12 €"
      f.input :half_price_cents, :hint => "Prix en centimes d'euros. Ex: entrez 500 pour un prix de 5 €"
      f.input :capacity
      f.input :name
      f.input :description
      f.input :location
      f.input :moment, as: :check_boxes, collection: ["Journée", "Matin", "Après-midi"]
    end
    f.actions
  end

  index do
    column :period_start
    column :name
    column :location
    column :capacity
    actions
  end

  controller do

    def create
      if params[:calendarupdate][:period_start] != "" && params[:calendarupdate][:period_end] != ""
        params[:calendarupdate][:period_end] = params[:calendarupdate][:period_start]
        p_start = define_period_bound(params[:calendarupdate][:period_start])
        p_end = define_period_bound(params[:calendarupdate][:period_end])
        if p_end < p_start
          flash[:alert] = "Erreur : date de fin doit être après date de début"
          redirect_to admin_calendarupdates_path and return
        end
      else
        flash[:alert] = "Impossible d'effectuer l'action : certains champs n'étaient pas remplis"
        redirect_to admin_calendarupdates_path and return
      end
      super do |format|
        moments = params[:calendarupdate][:moment].join("†")
        Calendarupdate.last.update(
          period_end: Calendarupdate.last.period_start + 23.hours,
          available: true,
          moment: moments,
          capacity: Calendarupdate.last.capacity,
          capacity_am: moments.include?("Matin") ? Calendarupdate.last.capacity : 0,
          capacity_pm: moments.include?("Après-midi") ? Calendarupdate.last.capacity : 0
        ) if resource.valid?
        redirect_to admin_calendarupdates_path and return if resource.valid?
      end
    end

    def update
      if resource.lessons
        flash[:alert] = "Impossible de modifier le stage : des réservations sont en cours ou payées"
        redirect_to admin_calendarupdates_path and return
      end
      super do |format|
        moments = params[:calendarupdate][:moment].join("†")
        Calendarupdate.find(params[:id]).update(moment: moments)
        redirect_to admin_calendarupdates_path and return if resource.valid?
      end
    end

    def destroy
      calendarupdate = Calendarupdate.find(params[:id])
      if Lesson.where(calendarupdate: calendarupdate).present?
        flash[:alert] = "Impossible de supprimer le stage :des réservations existent"
        redirect_to admin_calendarupdates_path
      else
        calendarupdate.destroy
        redirect_to admin_calendarupdates_path
      end
    end

    #Helper methods

    def define_period_bound(params_calendarupdate_periodbound)
      bounds = []
      for i in 0..2
        bounds << params_calendarupdate_periodbound.split('-').each.map {|string| string.to_i}[i]
      end
      output = DateTime.new(bounds[0],bounds[1],bounds[2])
      return output
    end

  end
end
