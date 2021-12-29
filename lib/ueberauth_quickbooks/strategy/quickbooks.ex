defmodule Ueberauth.Strategy.Quickbooks do
  @moduledoc """
  Quickbooks Strategy for Überauth.
  """
  
  use Ueberauth.Strategy,
    uid_field: :sub,
    default_scope: "com.intuit.quickbooks.accounting",
    hd: nil,
    userinfo_endpoint: "https://sandbox-accounts.platform.intuit.com/v1/openid_connect/userinfo"
  
  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles initial request for QuickBooks authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    params =
      [scope: scopes]
      |> with_optional(:hd, conn)
      |> with_optional(:prompt, conn)
      |> with_optional(:access_type, conn)
      |> with_optional(:login_hint, conn)
      |> with_optional(:include_granted_scopes, conn)
      |> with_param(:access_type, conn)
      |> with_param(:prompt, conn)
      |> with_param(:login_hint, conn)
      |> with_state_param(conn)

    opts = oauth_client_options_from_conn(conn)
    redirect!(conn, Ueberauth.Strategy.QuickBooks.OAuth.authorize_url!(params, opts))
  end

  @doc """
  Handles the callback from QuickBooks.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    params = [code: code]
    opts = oauth_client_options_from_conn(conn)

    case Ueberauth.Strategy.QuickBooks.OAuth.get_access_token(params, opts) do
      {:ok, token} ->
        fetch_user(conn, token)

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:quickbooks_user, nil)
    |> put_private(:quickboos_token, nil)
  end

  @doc """
  Fetches the uid field from the response.
  """
  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string

    conn.private.quickbooks_user[uid_field]
  end

  @doc """
  Includes the credentials from the quickbooks response.
  """
  def credentials(conn) do
    token = conn.private.quickbooks_token
    scope_string = token.other_params["scope"] || ""
    scopes = String.split(scope_string, ",")

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      scopes: scopes,
      token_type: Map.get(token, :token_type),
      refresh_token: token.refresh_token,
      token: token.access_token
    }
  end

  @doc """
  Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
  """
  def info(conn) do
    user = conn.private.quickbooks_user

    %Info{
      email: user["email"],
      first_name: user["given_name"],
      image: user["picture"],
      last_name: user["family_name"],
      name: user["name"],
      birthday: user["birthday"],
      urls: %{
        profile: user["profile"],
        website: user["hd"]
      }
    }
  end

  @doc """
  Stores the raw information (including the token) obtained from the quickbooks callback.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.quickbooks_token,
        user: conn.private.quickbooks_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :quickbooks_token, token)

    # userinfo_endpoint from https://accounts.quickbooks.com/.well-known/openid-configuration
    # the userinfo_endpoint may be overridden in options when necessary.
    resp = Ueberauth.Strategy.QuickBooks.OAuth.get(token, get_userinfo_endpoint(conn))

    case resp do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :quickbooks_user, user)

      {:error, %OAuth2.Response{status_code: status_code}} ->
        set_errors!(conn, [error("OAuth2", status_code)])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp get_userinfo_endpoint(conn) do
    case option(conn, :userinfo_endpoint) do
      {:system, varname, default} ->
        System.get_env(varname) || default

      {:system, varname} ->
        System.get_env(varname) || Keyword.get(default_options(), :userinfo_endpoint)

      other ->
        other
    end
  end

  defp with_param(opts, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(opts, key, value), else: opts
  end

  defp with_optional(opts, key, conn) do
    if option(conn, key), do: Keyword.put(opts, key, option(conn, key)), else: opts
  end

  defp oauth_client_options_from_conn(conn) do
    base_options = [redirect_uri: callback_url(conn)]
    request_options = conn.private[:ueberauth_request_options].options

    case {request_options[:client_id], request_options[:client_secret]} do
      {nil, _} -> base_options
      {_, nil} -> base_options
      {id, secret} -> [client_id: id, client_secret: secret] ++ base_options
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
