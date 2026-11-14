Rails.application.routes.draw do
  root "dashboard#show"
  get "/up", to: "probes#live"
  get "/ready", to: "probes#ready"
  get "/qa", to: "probes#status"
  get "/slow", to: "probes#slow"
  get "/api/status", to: "probes#status"
  get "/private", to: "probes#private_api"
  get "/api/jobs/:request_key", to: "work#show"
  post "/api/jobs", to: "work#create"
  mount ActionCable.server => "/cable"
end
