module SessionHelper
  EXPIRATE_AFTER = 1200 # seconds

  def user_signed_in?
    if omniauth_auth_email
      current_session = Session.active_session(omniauth_auth_email)
      return true if current_session && current_session.session_id_correct?(session[:session_id])
    end

    false
  end

  def omniauth_auth_email
    session.dig(:omniauth_auth, 'info', 'email')
  end
end
