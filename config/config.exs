use Mix.Config

config :ueberauth, Ueberauth,
  providers: [
    quickbooks: {Ueberauth.Strategy.Quickbooks, []}
  ]

config :ueberauth, Ueberauth.Strategy.QuickBooks.OAuth,
  client_id: "client_id",
  client_secret: "client_secret",
  token_url: "token_url"
