class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    email = auth&.dig("info", "email")

    allowed_email = ENV.fetch("DISPATCHER_ADMIN_EMAIL", "eliasmiranda.la@gmail.com").downcase

    unless email&.downcase == allowed_email
      render_popup("unauthorized", status: :forbidden)
      return
    end

    session[:dispatcher] = {
      uid: auth["uid"],
      email: email,
      name: auth.dig("info", "name"),
      image: auth.dig("info", "image")
    }

    render_popup("success")
  end

  def destroy
    session[:dispatcher] = nil
    head :no_content
  end

  def failure
    render_popup("failed", status: :unauthorized)
  end

  private

  def render_popup(result, status: :ok)
    frontend_url = URI.parse(ENV.fetch("FRONTEND_URL", "http://localhost:5173/dispatch"))
    @frontend_origin = frontend_url.origin
    @auth_result = result
    render "auth/popup", layout: false, status: status
  end
end
