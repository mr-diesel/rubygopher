# This file should ensure the existence of records required to run the application in every environment
# (production, development, test). The code here should be idempotent so that it can be executed at any
# point in every environment. The data can then be loaded with the bin/rails db:seed command.

if Rails.env.development?
  Admin.find_or_create_by!(email: "admin@rubygopher.local") do |admin|
    admin.password = "password123"
  end
  puts "Seeded admin: admin@rubygopher.local / password123"
end
