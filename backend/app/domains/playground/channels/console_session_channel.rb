module Playground
  module Channels
    # One stream per shared session. Edits are last-write-wins: the server stores
    # whatever arrived last and relays it to everyone else.
    class ConsoleSessionChannel < ApplicationCable::Channel
      def subscribed
        @session = ConsoleSession.active.find_by(token: params[:token])
        return reject unless @session

        @member_id = SecureRandom.uuid
        stream_for @session
        count = Presence.join(@session, @member_id)
        transmit(@session.state.merge(type: "state", by: nil, participants: count))
        @session.broadcast(type: "presence", participants: count)
      end

      def unsubscribed
        return unless @session

        count = Presence.leave(@session, @member_id)
        @session.broadcast(type: "presence", participants: count, left: current_user.id)
      end

      def update(data)
        @session.apply!(code: data["code"].to_s, context: data["context"].to_s, by: current_user.id)
      end

      def running(_data)
        @session.broadcast(type: "running", by: current_user.id)
      end

      def cursor(data)
        @session.broadcast(type: "cursor", by: current_user.id, name: current_user.name.presence || current_user.email, pos: data["pos"].to_i)
      end
    end
  end
end
