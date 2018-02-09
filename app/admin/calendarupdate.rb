ActiveAdmin.register Calendarupdate do
  permit_params :period_start, :period_end
  actions  :index, :new, :create, :destroy, :show
  menu priority: 4
  config.filters = false

  form do |f|
    f.inputs "" do
      f.input :period_start, as: :datepicker
      f.input :period_end, as: :datepicker
    end
    f.actions
  end

  index_as_calendar do |calendarupdate|
    {
      title: "Période bloquée",
      start: calendarupdate.period_start,
      end: calendarupdate.period_end + 1.day,
      url: "#{admin_calendarupdate_path(calendarupdate)}",
      textColor: '#2A2827',
    }
  end

  index do
    column :period_start
    column :period_end
    actions
  end

  controller do

    def create
      if params[:calendarupdate][:period_start] != "" && params[:calendarupdate][:period_end] != ""
        p_start = define_period_bound(params[:calendarupdate][:period_start])
        p_end = define_period_bound(params[:calendarupdate][:period_end])
        if p_end < p_start
          flash[:alert] = "Erreur : date de fin doit être après date de début"
          redirect_to admin_calendarupdates_path and return
        end
        day_checked = p_start
        period_ok = period_check(p_start, p_end)
        if period_ok
          while day_checked <= p_end
            Booking.create(day: day_checked, capacity: 0, capacity_am: 0, capacity_pm: 0, course: 0, duration: 0, full: true)
            day_checked += 1.day
          end
        else
          flash[:alert] = "Impossible de bloquer la période : certains jours étaient déjà occupés par des réservations confirmées"
          redirect_to admin_calendarupdates_path and return
        end
      else
        flash[:alert] = "Impossible de bloquer la période : certains champs n'étaient pas remplis"
        redirect_to admin_calendarupdates_path and return
      end

      super do |format|
        last_calendar = Calendarupdate.last
        Lesson.create(
          start: p_start,
          student: ENV['CAPACITY'].to_i,
          duration: (p_end - p_start).to_i + 1,
          user: current_user,
          confirmed: true,
          )
        last_lesson = Lesson.last
        last_calendar.update(lesson: last_lesson)
        redirect_to admin_lessons_path and return
      end
    end

    #Helper methods

    def destroy
      calendarupdate = Calendarupdate.find(params[:id])
      lesson = calendarupdate.lesson
      destroy_associated_bookings(calendarupdate)
      calendarupdate.destroy
      lesson.destroy
      redirect_to admin_calendarupdates_path
    end

    def period_check(day_start, day_end)
      period_ok = true
      day_checked = day_start
      p_end = day_end
      while day_checked <= p_end
          if Booking.where("day = ? AND capacity < ?", day_checked, ENV['CAPACITY'].to_i).present?
            period_ok = false
          end
          day_checked += 1.day
        end
      return period_ok
    end

    def define_period_bound(params_calendarupdate_periodbound)
      bounds = []
      for i in 0..2
        bounds << params_calendarupdate_periodbound.split('-').each.map {|string| string.to_i}[i]
      end
      output = DateTime.new(bounds[0],bounds[1],bounds[2])
      return output
    end

    def destroy_associated_bookings(calendarupdate)
      p_start = calendarupdate.period_start
      p_end = calendarupdate.period_end
      day_checked = p_start
      while day_checked <= p_end
        booking = Booking.where(day: day_checked).first
        if booking.duration == 0
          booking.destroy
        end
        day_checked += 1.day
      end
    end

  end
end
