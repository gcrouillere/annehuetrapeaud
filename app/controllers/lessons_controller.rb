class LessonsController < ApplicationController
  layout 'stage'
  skip_before_action :authenticate_user!, only: [:show, :new]

  def new
    @dev_redirection = "https://www.creermonecommerce.fr/lessons/new"
    @lesson = Lesson.new
    @available_courses = Calendarupdate.where(available: true).order(period_start: :asc)
    @formatted_moments = Calendarupdate.formatted_moments(@available_courses)
    @courses_to_display = Calendarupdate.format_stages_ref(@available_courses)
    @twitter_url = request.original_url.to_query('url')
  end

  def create
    if current_user.lessons.where(confirmed: false).present?
      flash[:alert] = "Vous avez déjà une réservation en cours"
      redirect_to new_lesson_path and return
    end

    @calendar_update = Calendarupdate.find(params[:lesson][:stage_id])

    @lesson = Lesson.new(
      start: @calendar_update.period_start,
      duration: (@calendar_update.period_end - @calendar_update.period_start).round / (24 * 3600) + 1,
      student: params[:lesson][:student].to_i,
      user_id: params[:lesson][:user_id].to_i,
      confirmed: false,
      moment: params[:lesson][:moment].split(" - ")[0],
      calendarupdate: @calendar_update
    )
    if capacity_check(@calendar_update, @lesson)
      @lesson.save
      am_pm_booking_management(@calendar_update, @lesson)
      create_order_for_lesson(@lesson)
      flash[:notice] = "Votre réservation sera conservée 30 min"
      redirect_to lesson_path(@lesson)
    else
      flash[:alert] = "Impossible de réserver. Plus que #{@calendar_update.capacity} place(s) disponible(s) pour ce stage"
      redirect_to new_lesson_path and return
    end
  end

  def show
    @lesson = Lesson.find(params[:id])
    @user = @lesson.user
    @order = Order.where(lesson: @lesson).first
  end

  def stage_confirmation
  end

  def stage_payment_confirmation
  end

  private

  def lesson_params
    params.require(:lesson).permit(:start, :duration, :student, :user_id, :moment)
  end

  def capacity_check(calendar_update, lesson)
    output = false
    if lesson.moment == "Matin"
      output = true if lesson.student < calendar_update.capacity_am
    elsif lesson.moment == "Après-midi"
      output = true if lesson.student < calendar_update.capacity_pm
    else
      output = true if lesson.student < calendar_update.capacity
    end
    return output
  end

  def am_pm_booking_management(calendar_update, lesson)
    if lesson.moment == "Matin"
      calendar_update.update(capacity: calendar_update.capacity - lesson.student, capacity_am: calendar_update.capacity_am - lesson.student)
    elsif lesson.moment == "Après-midi"
      calendar_update.update(capacity: calendar_update.capacity - lesson.student, capacity_pm: calendar_update.capacity_pm - lesson.student)
    else
      calendar_update.update(capacity: calendar_update.capacity - lesson.student, capacity_am: calendar_update.capacity_am - lesson.student, capacity_pm: calendar_update.capacity_pm - lesson.student)
    end
    calendar_update.update(available: false) if calendar_update.capacity <= 0
  end

  def create_order_for_lesson(lesson)
    amount = lesson.moment == "Journée" ? lesson.calendarupdate.full_price_cents : lesson.calendarupdate.half_price_cents

    Order.create!(
      state: 'pending',
      amount_cents: amount,
      user: lesson.user,
      lesson: lesson,
      take_away: false
    )
  end
end
