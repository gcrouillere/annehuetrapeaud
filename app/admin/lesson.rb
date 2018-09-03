ActiveAdmin.register Lesson do
  permit_params :confirmed
  actions  :index, :destroy, :update, :edit, :show
  config.sort_order = 'start_asc'
  menu priority: 5
  config.filters = false

  index do
    render 'current_week_lessons'
    column "Début" do |lesson|
       "#{lesson.start.day} #{lesson.start.strftime("%B")} #{lesson.start.year}"
    end
    column :student
    column "Client" do |lesson|
      lesson.user.email
    end
    column :confirmed
    column "Payée ?" do |lesson|
      order = Order.where(lesson: lesson).first
      order.present? ? order.state == "paid" : false
    end
  end

  index_as_calendar ({:ajax => false}) do |lesson|
    #Caractéristiques des évènements à afficher
    confirmation = ""
    lesson.confirmed ? confirmation = "oui" : confirmation = "non"
    Calendarupdate.where(lesson: lesson).present? ? is_a_calendarupdate = true : is_a_calendarupdate = false
    order = Order.where(lesson: lesson).first
    order.present? ? (order.state == "paid" ? payment = "oui" : payment = "non") : payment = "non"
    order.present? ? (order.state == "paid" ? is_paid = true : is_paid = false) : is_paid = false

    #Paramètres pour index_as_calendar
    {
      title: is_a_calendarupdate ? "Période bloquée" : "#{lesson.moment} - #{lesson.student} personnes - Confirmée: #{confirmation} - Payée: #{payment}",
      start: lesson.start,
      end: (lesson.start + lesson.duration.day),
      url: "#{admin_lesson_path(lesson)}",
      textColor: '#2A2827',
      color: is_a_calendarupdate ? '#3a87ad' : (is_paid ? '#8CE35E' : (lesson.confirmed ? '#FFD938' : '#FF9E6A'))

    }
  end

  show do |lesson|
    attributes_table do
      row "Début" do
       "#{lesson.start.day} #{lesson.start.strftime("%B")} #{lesson.start.year}"
      end
      row :duration
      row :user
      row :confirmed
      row :moment
      if Calendarupdate.where(lesson: lesson).blank?
        row :student
        row "Paiement" do |lesson|
          Order.where(lesson: lesson).present? ? (Order.where(lesson: lesson).first.state == "pending" ? "Non payé" : "Payé") : "Non payé"
        end
      else
        row "Type" do |lesson|
          "Période bloquée"
        end
      end
    end
  end

  controller do

    def index
      super do |format|
        @current_week_lessons_a = Lesson.where("confirmed = ? AND start >= ?", true, Time.now - 20 * 3600 * 24).joins(:order).order(start: :asc).where("lesson_id IS NOT NULL")
        @pending_lessons = Lesson.where("confirmed = ? AND start >= ?", false, Time.now)
        Lesson.all.each do |lesson|
          if !lesson.confirmed? && lesson.start < Time.now
            lesson.destroy
          end
        end
      end
    end

    def update
      lesson = Lesson.find(params[:id].to_i)
      lesson_ok = false
      # Mise à jour ou création des bookings sur chaque jour
      if params[:lesson][:confirmed] == "1" && lesson.confirmed == false # Si la réservation va être confirmée
        if period_available_for_lesson(lesson) # Si la période est dispo
          bookings_creation(lesson)
          create_order_for_lesson(lesson)
          LessonMailer.mail_user_after_confirmation(lesson).deliver_now
        else
          flash[:alert] = "Chevauchement de réservations ou capacité insuffisante, confirmation impossible. Il faut : soit supprimer cette demande, soit annuler une réservation déjà confirmée."
          redirect_to admin_lessons_path and return
        end
        lesson.update(confirmed: true)
        redirect_to admin_lessons_path and return
      end
      redirect_to admin_lessons_path unless lesson_ok
    end

    def destroy
      lesson = Lesson.find(params[:id].to_i)
      calendarupdate = Calendarupdate.where(lesson: lesson).first
      bookings_deletion(lesson)
      if calendarupdate
        calendarupdate.destroy
      else
        order = Order.where(lesson: lesson).first
        order_destroy_if_pending(order)
        LessonMailer.mail_user_after_lesson_destroy(lesson).deliver_now
      end

      super do |format|
        redirect_to admin_lessons_path and return if resource.valid?
      end
    end

    #Helper methods

    def period_available_for_lesson(lesson)
      period_ok = true
      for i in 0...lesson.duration
        day_checked = lesson.start + i.day
        booking = Booking.where(day: day_checked).first
        if booking.present?
          if booking.course != i + 1 || lesson.student > booking.capacity
            if lesson.moment == "matin"
              lesson.student > booking.capacity_am ? period_ok = false : nil
            elsif lesson.moment == "après-midi"
              lesson.student > booking.capacity_am ? period_ok = false : nil
            else
              lesson.student > booking.capacity_am || lesson.student > booking.capacity_pm ? period_ok = false : nil
            end
          end
        end
      end
      return period_ok
    end

    #Next method modified for Huet Rapeaud
    def create_order_for_lesson(lesson)
      amount = 0.0
      if lesson.moment == "matin"
       amount = ENV['TWODAYSLESSONPRICE'].to_f * lesson.student.to_f * ENV['LESSONDEPOSITRATIO'].to_f
      elsif lesson.moment == "après-midi"
       amount = ENV['FIVEDAYSLESSONPRICE'].to_f * lesson.student.to_f * ENV['LESSONDEPOSITRATIO'].to_f
      else
        amount = ENV['FULLLESSONPRICE'].to_f * lesson.student.to_f * ENV['LESSONDEPOSITRATIO'].to_f
     end
      Order.create!(
        state: 'pending',
        amount_cents: amount * 100,
        user: lesson.user,
        lesson: lesson,
        take_away: false
      )
    end

    def bookings_creation(lesson)
      previous_booking_full = false
      for i in 0...lesson.duration
        day_checked = lesson.start + i.day
        if Booking.where(day: day_checked).present? # Si un cours existe déjà ce jour
          booking = Booking.where(day: day_checked).first
          # next 2 lines modified for Huet Rapeaud
          am_pm_booking_management(lesson, booking)
          booking_capacity_check_with_am_pm(lesson, booking)
          if lesson.duration == ENV['MAXDURATION'].to_i
            booking.update(duration: ENV['MAXDURATION'].to_i)
          end
        else
          # next line modified for Huet Rapeaud
          booking_creation(day_checked, lesson, i)
          booking = Booking.last
        end
        previous_booking_full = booking.full
      end
    end

    def bookings_deletion(lesson)
      if lesson.confirmed?
        for i in 0...lesson.duration
          day_checked = lesson.start + i.day
          booking = Booking.where(day: day_checked).first
          am_pm_booking_management(lesson, booking)
          if booking.capacity >= 2 * (ENV['CAPACITY'].to_i)
            booking.destroy
          end
        end
      end
    end

    def order_destroy_if_pending(order)
      if order
        order.update(lesson: nil)
        if order.state == "pending"
          order.destroy
        end
      end
    end

    # Huet Rapeaud Specific
    def am_pm_booking_management(lesson, booking)
      if params[:action] == "update"
        if lesson.moment == "matin"
          booking.update(capacity: booking.capacity - lesson.student, capacity_am: booking.capacity_am - lesson.student)
        elsif lesson.moment == "après-midi"
          booking.update(capacity: booking.capacity - lesson.student, capacity_pm: booking.capacity_pm - lesson.student)
        else
          booking.update(capacity: booking.capacity - 2 * lesson.student, capacity_am: booking.capacity_am - lesson.student, capacity_pm: booking.capacity_pm - lesson.student)
        end
      end
      if params[:action] == "destroy"
        if lesson.moment == "matin"
          booking.update(capacity: booking.capacity + lesson.student, capacity_am: booking.capacity_am + lesson.student)
        elsif lesson.moment == "après-midi"
          booking.update(capacity: booking.capacity + lesson.student, capacity_pm: booking.capacity_pm + lesson.student)
        else
          booking.update(capacity: booking.capacity + 2 * lesson.student, capacity_am: booking.capacity_am + lesson.student, capacity_pm: booking.capacity_pm + lesson.student)
        end
        booking.update(full: false)
      end
    end

    def booking_capacity_check_with_am_pm(lesson, booking)
      if booking.capacity_am < ENV['MINBOOKING'].to_i
        booking.update(capacity_am: 0)
      end
      if booking.capacity_pm < ENV['MINBOOKING'].to_i
        booking.update(capacity_pm: 0)
      end
      if booking.capacity_am == 0 && booking.capacity_pm == 0
        booking.update(full: true, capacity: 0)
      end
    end

    def booking_creation(day_checked, lesson, i)
      if lesson.moment == "matin"
        booking = Booking.create(day: day_checked, capacity: 2 * ENV['CAPACITY'].to_i - lesson.student, capacity_am: ENV['CAPACITY'].to_i - lesson.student, capacity_pm: ENV['CAPACITY'].to_i, course: i + 1, duration: lesson.duration)
        booking.update(full: true) if Booking.last.capacity < ENV['MINBOOKING'].to_i
      elsif lesson.moment == "après-midi"
        booking = Booking.create(day: day_checked, capacity: 2 * ENV['CAPACITY'].to_i - lesson.student, capacity_am: ENV['CAPACITY'].to_i, capacity_pm: ENV['CAPACITY'].to_i - lesson.student, course: i + 1, duration: lesson.duration)
        booking.update(full: true) if Booking.last.capacity < ENV['MINBOOKING'].to_i
      else
        booking = Booking.create(day: day_checked, capacity: 2 * ENV['CAPACITY'].to_i - lesson.student, capacity_am: ENV['CAPACITY'].to_i - lesson.student, capacity_pm: ENV['CAPACITY'].to_i - lesson.student, course: i + 1, duration: lesson.duration)
        booking.update(full: true) if Booking.last.capacity < ENV['MINBOOKING'].to_i
      end
    end
    #Huet Rapeaud specific end

  end
end
