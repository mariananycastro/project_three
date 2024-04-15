require 'spec_helper'
require 'pry'

RSpec.describe Session, type: :model do
  describe '.create' do
    context 'with valid attributes' do
      it 'creates a session' do
        session_id = '123456789'
        session = Session.create(
          session_id: session_id,
          email: 'user_email@mail.com',
          expires_at: 1.day.from_now
        )

        expect(session).to be_a Session
        expect(session.session_id_digest).not_to eq(session_id)
      end
    end

    context 'missing attributes' do
      it 'raise some error' do
        session = Session.create(
          session_id: nil,
          email: nil,
          expires_at: nil
        )

        expect(session.id).to be nil
        expect(session.errors.full_messages).to eq(
          [
            "Email can't be blank",
            "Expires at can't be blank",
            "Session id digest can't be blank"
          ]
        )
      end
    end
  end

  describe '#session_id_correct?' do
    let(:session) do
      Session.create(
        session_id: '123456789',
        email: 'user_email@mail.com',
        expires_at: 1.day.from_now
      )
    end
    subject(:session_id_correct?) { session.session_id_correct?(current_session_id) }

    context 'when invalid session_id is given' do
      let(:current_session_id) { '11111111' }

      it { is_expected.to be false }
    end

    context 'when valid session_id is given' do
      let(:current_session_id) { '123456789' }

      it { is_expected.to be true }
    end
  end

  describe '.active_sessions' do
    let(:email) { 'user_email@mail.com' }
    let(:active_session) do
      Session.create(
        session_id: '123456789',
        email: email,
        expires_at: 1.day.from_now
      )
    end
    let(:inactive_session) do
      Session.create(
        session_id: '123456789',
        email: email,
        expires_at: 1.day.ago
      )
    end

    context 'when user email has sessions' do
      context 'when there is active session' do
        before do
          active_session
          inactive_session
        end
  
        it 'returns only active sessions' do
          active_sessions = Session.active_sessions(email)

          expect(active_sessions.count).to eq 1
          expect(active_sessions.first.id).to eq active_session.id
        end      
      end
  
      context 'when there is NO active session' do
        before do
          inactive_session
        end
  
        it 'returns only active sessions' do
          active_sessions = Session.active_sessions(email)

          expect(active_sessions.count).to eq 0
        end      
      end
    end

    context 'when user email does not have sessions' do
      before do 
        active_session
        inactive_session
      end

      it 'returns empty array' do
        active_sessions = Session.active_sessions('another_email@email.com')

        expect(active_sessions.count).to eq 0
      end
    end
  end

  describe '.active_session' do
    let(:email) { 'user_email@mail.com' }
    let(:active_session_first) do
      Session.create(
        session_id: '123456789',
        email: email,
        expires_at: 1.day.from_now
      )
    end
    let(:active_session_last) do
      Session.create(
        session_id: '987654321',
        email: email,
        expires_at: 2.day.from_now
      )
    end

    context 'when user has active sessions' do
      before do
        active_session_first
        active_session_last
      end

      it 'returns the last one' do
        current_session = Session.active_session(email)

        expect(current_session.id).to eq active_session_last.id
      end
    end

    context 'when user has NO active sessions' do
      before do
        active_session_first
        active_session_last
      end

      it 'returns nil' do
        current_session = Session.active_session('another_email@email.com')

        expect(current_session).to eq nil
      end
    end
  end

  describe '.expire_all' do
    let(:email) { 'user_email@mail.com' }
    let(:active_session_first) do
      Session.create(
        session_id: '123456789',
        email: email,
        expires_at: 1.day.from_now
      )
    end
    let(:active_session_last) do
      Session.create(
        session_id: '987654321',
        email: email,
        expires_at: 2.days.from_now
      )
    end
    let(:inactive_session) do
      Session.create(
        session_id: '11111111',
        email: email,
        expires_at: 1.day.ago
      )
    end

    context 'when there is active sessions' do
      before do
        active_session_first
        active_session_last
        inactive_session
      end
      subject(:expire_all) { Session.expire_all(email) }

      it 'expires active sessions' do
        expect {
          subject
          active_session_first.reload
          active_session_last.reload
        }
          .to change { active_session_first.expires_at }
          .and change { active_session_last.expires_at }
      end

      it 'does NOT update already expired session' do
        expect { subject }.not_to change { inactive_session.reload.expires_at }
      end
    end
  end
end
