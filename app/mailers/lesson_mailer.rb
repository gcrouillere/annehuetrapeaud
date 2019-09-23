class LessonMailer < ApplicationMailer

  def mail_user_after_lesson_destroy(lesson)
    @lesson = lesson
    @closest_start = Findcloseststart.new(@lesson).closest_start(@lesson)
    if @lesson.confirmed
      mail(to: @lesson.user.email, subject: "Annulation de votre stage chez #{ENV['FIRSTNAME'].capitalize} #{ENV['LASTNAME'].capitalize}")
    else
      mail(to: @lesson.user.email, subject: "Refus de votre demande de stage chez #{ENV['FIRSTNAME'].capitalize} #{ENV['LASTNAME'].capitalize}")
    end
  end

  def mail_user_after_confirmation(lesson)
    @lesson = lesson
    mail(to: @lesson.user.email, subject: "Confirmation de votre stage chez #{ENV['FIRSTNAME'].capitalize} #{ENV['LASTNAME'].capitalize}")
  end

  def mail_francoise_after_lesson_create(lesson)
    @lesson = lesson
    mail(to: "#{ENV['EMAIL']}", subject: 'Nouvelle demande de stage reçue')
  end

  def mail_user_after_lesson_payment(lesson, user)
    @lesson = lesson
    @user = user
    mail(to: @lesson.user.email, subject: "Paiement pour votre stage chez #{ENV['FIRSTNAME'].capitalize} #{ENV['LASTNAME'].capitalize}")
  end

  def mail_francoise_after_lesson_payment(lesson, user)
    @lesson = lesson
    mail(to: "#{ENV['EMAIL']}", subject: 'Paiement pour stage recu')
  end

end
