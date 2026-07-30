Rails.autoloaders.each do |loader|
  loader.inflector.inflect("api" => "API")
end
