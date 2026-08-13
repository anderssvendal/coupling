Coupling.configure do |config|
  config.assets_path = Rails.root.join("coupled_assets")
  config.public_path = "/coupled-assets"
end
