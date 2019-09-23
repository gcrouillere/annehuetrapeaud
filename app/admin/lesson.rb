ActiveAdmin.register Lesson do
  permit_params :confirmed
  actions  :index, :destroy, :show
  config.sort_order = 'start_asc'
  menu priority: 5
  config.filters = false

  index do
    render 'current_week_lessons'
    column "Début" do |lesson|
       lesson.start.strftime("%d/%m/%Y")
    end
    column :student
    column "Client" do |lesson|
      lesson.user.email
    end
    column "Payée ?" do |lesson|
      order = Order.where(lesson: lesson).first
      order.present? ? order.state == "paid" : false
    end
    actions
  end

  show do |lesson|
    attributes_table do
      row "Début" do
       "#{lesson.start.day} #{lesson.start.strftime("%B")} #{lesson.start.year}"
      end
      row :user
      row :student
      row :moment
      row "Payée ?" do |lesson|
        order = Order.where(lesson: lesson).first
        order.present? ? order.state == "paid" : false
      end
    end
  end

  controller do

    def index
      super do |format|
        @current_week_lessons_a = Lesson.where("confirmed = ? AND start >= ?", true, Time.now - 20 * 3600 * 24).joins(:order).order(start: :asc).where("lesson_id IS NOT NULL")
        Lesson.all.each do |lesson|
          if !lesson.confirmed? && lesson.start < Time.now
            lesson.destroy
          end
        end
      end
    end

    def destroy
      lesson = Lesson.find(params[:id].to_i)
      if lesson.order.state == 'paid'
        flash[:alert] = "Cette réservation est payée, vous ne pouvez pas la supprimer"
        redirect_to request.referrer and return
      end

      order = Order.where(lesson: lesson).first
      order_destroy_if_pending(order)
      am_pm_booking_management(lesson, lesson.calendarupdate)

      super do |format|
        redirect_to admin_lessons_path and return if resource.valid?
      end
    end

    # Huet Rapeaud Specific

    def order_destroy_if_pending(order)
      if order
        order.update(lesson: nil)
        if order.state == "pending"
          order.destroy
        end
      end
    end

    def am_pm_booking_management(lesson, calendarupdate)
      if lesson.moment == "Matin"
        calendarupdate.update(capacity: calendarupdate.capacity + lesson.student, capacity_am: calendarupdate.capacity_am + lesson.student)
      elsif lesson.moment == "Après-midi"
        calendarupdate.update(capacity: calendarupdate.capacity + lesson.student, capacity_pm: calendarupdate.capacity_pm + lesson.student)
      else
        calendarupdate.update(capacity: calendarupdate.capacity * lesson.student, capacity_am: calendarupdate.capacity_am + lesson.student, capacity_pm: calendarupdate.capacity_pm + lesson.student)
      end
      calendarupdate.update(available: true)
    end

    #Huet Rapeaud specific end
  end
end
