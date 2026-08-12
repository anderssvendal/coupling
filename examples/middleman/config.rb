require 'coupling/middleman'

activate :coupling do |config|
end

# Make sure Middleman does not try to compile anything in assets/
ignore 'assets/**'
