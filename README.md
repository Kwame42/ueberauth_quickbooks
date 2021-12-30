# Überauth Intuit Quickbooks

> Quickbooks OAuth2 strategy for Überauth.

## Installation

1.  Setup your application at [Intuit Developer](https://developer.intuit.com/app/developer/qbo/docs/develop).

2.  Add `:ueberauth_quickbooks` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [
        {:ueberauth_quickbooks, "~> 0.01"}
      ]
    end
    ```

3.  Add Quickbooks to your Überauth configuration:

    ```elixir
    config :ueberauth, Ueberauth,
      providers: [
        google: {Ueberauth.Strategy.Quickbooks, []}
      ]
    ```

4.  Update your provider configuration:

    Use that if you want to read client ID/secret from the environment
    variables in the compile time:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.Quickbooks.OAuth,
      client_id: System.get_env("QUICKBOOKS_CLIENT_ID"),
      client_secret: System.get_env("QUICKBOOKS_CLIENT_SECRET")
    ```

    Use that if you want to read client ID/secret from the environment
    variables in the run time:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.Quickbooks.OAuth,
      client_id: {System, :get_env, ["QUICKBOOKS_CLIENT_ID"]},
      client_secret: {System, :get_env, ["QUICKBOOKS_CLIENT_SECRET"]}
    ```

5.  Include the Überauth plug in your controller:

    ```elixir
    defmodule MyApp.AuthController do
      use MyApp.Web, :controller
      plug Ueberauth
      ...
    end
    ```

6.  Create the request and callback routes if you haven't already:

    ```elixir
    scope "/auth", MyApp do
      pipe_through :browser

      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
    end
    ```

7.  Your controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses.

For an example implementation see the [Überauth Example](https://github.com/ueberauth/ueberauth_example) application.

## Calling

Depending on the configured url you can initiate the request through:

    /auth/quickbooks

Or with options:

    /auth/quickbooks?scope=email%20profile

By default the requested scope is "email". Scope can be configured either explicitly as a `scope` query value on the request path or in your configuration:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    quickbooks: {Ueberauth.Strategy.Quickbooks, [default_scope: "email profile plus.me"]}
  ]
```

You can also pass options such as the `hd` parameter to suggest a particular Quickbooks Apps hosted domain (caution, can still be overridden by the user), `prompt` and `access_type` options to request refresh_tokens and offline access (both have to be present), or `include_granted_scopes` parameter to allow [incremental authorization](https://developers.quickbooks.com/identity/protocols/oauth2/web-server#incrementalAuth).

```elixir
config :ueberauth, Ueberauth,
  providers: [
    quickbooks: {Ueberauth.Strategy.Quickbooks, [hd: "example.com", prompt: "select_account", access_type: "offline", include_granted_scopes: true]}
  ]
```

In some cases, it may be necessary to update the user info endpoint, such as when deploying to countries that block access to the default endpoint.

```elixir
config :ueberauth, Ueberauth,
  providers: [
    quickbooks: {Ueberauth.Strategy.Quickbooks, [userinfo_endpoint: "https://www.quickbooksapis.cn/oauth2/v3/userinfo"]}
  ]
```

This may also be set via runtime configuration by passing a 2 or 3 argument tuple. To use this feature, the first argument must be the atom `:system`, and the second argument must represent the environment variable containing the endpoint url.
A third argument may be passed representing a default value if the environment variable is not found, otherwise the library default will be used.

```elixir
config :ueberauth, Ueberauth,
  providers: [
    quickbooks: {Ueberauth.Strategy.Quickbooks, [
      userinfo_endpoint: {:system, "QUICKBOOKS_USERINFO_ENDPOINT", "https://www.quickbooksapis.cn/oauth2/v3/userinfo"}
    ]}
  ]
```

To guard against client-side request modification, it's important to still check the domain in `info.urls[:website]` within the `Ueberauth.Auth` struct if you want to limit sign-in to a specific domain.

## Thanks

This code is mostly a copy of [ueberauth_google](https://github.com/ueberauth/ueberauth_google) and modified in consequence.

## Copyright and License

Copyright (c) 2021 Kwame Yamgnane

Released under the MIT License, which can be found in the repository in [LICENSE](https://github.com/ueberauth/ueberauth_quickbooks/blob/master/LICENSE).
