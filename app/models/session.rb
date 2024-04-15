require 'sinatra/activerecord'
require 'bcrypt'

class Session < ActiveRecord::Base
  encrypts :email, deterministic: true
  validates :email, :expires_at, :session_id_digest, presence: true

  def initialize(attributes = {})
    super(attributes)
    self.session_id = attributes[:session_id] if attributes[:session_id]
  end

  def session_id=(new_session_id)
    if new_session_id
      self[:session_id_digest] = BCrypt::Password.create(new_session_id)
    end
  end

  # Method to verify the session ID
  def session_id_correct?(session_id)
    BCrypt::Password.new(session_id_digest) == session_id
  end

  def self.active_sessions(user_email)
    where(email: user_email).where('expires_at >= ?', Time.now)
  end

  def self.active_session(user_email)
    active_sessions(user_email).last
  end

  def self.expire_all(user_email)
    user_active_sessions = active_sessions(user_email)

    user_active_sessions.update_all(expires_at: 1.minute.ago)
  end
end
