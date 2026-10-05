Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow localhost and private-network origins on the Vite port (LAN access in dev).
    origins do |source, _env|
      next true if source == ENV["FRONTEND_ORIGIN"]

      source&.match?(%r{\Ahttps?://(localhost|127\.0\.0\.1|(?:192\.168|10)\.\d+\.\d+|172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+):5173\z})
    end

    resource "/api/*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: [ "Authorization" ]
  end
end
