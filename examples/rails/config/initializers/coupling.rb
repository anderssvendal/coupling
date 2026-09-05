Coupling.configure do |config|
  config.assets_path = Rails.root.join("../assets").expand_path
  config.public_path = "/coupled-assets"
end
