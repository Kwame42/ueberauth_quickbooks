defmodule Ueberauth.Strategy.Quickbooks do
  @moduledoc """
  Quickbooks Strategy for Überauth.
  """
  
  use Ueberauth.Strategy,
#    uid_field: :sub,
    default_scope: "com.intuit.quickbooks.accounting",
    hd: nil,
    userinfo_endpoint: "https://sandbox-accounts.platform.intuit.com/v1/openid_connect/userinfo"
  
  alias Ueberauth.Auth.Credentials

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
    opts = oauth_client_options_from_conn(conn) ++ code_options_from_conn(conn)
    
    case Ueberauth.Strategy.QuickBooks.OAuth.get_access_token(params, opts) do
      {:ok, token} -> put_private(conn, :quickbooks_token, token)
      {:error, {error_code, error_description}} -> set_errors!(conn, [error(error_code, error_description)])
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
    |> put_private(:quickbooks_token, nil)
  end

  @doc """
  Includes the credentials from the quickbooks response.
  """
  def credentials(conn) do
    token = conn.private.quickbooks_token

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      token_type: Map.get(token, :token_type),
      refresh_token: token.refresh_token,
      token: token.access_token,
      other: token.other_params
    }
  end

  defp with_param(opts, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(opts, key, value), else: opts
  end

  defp with_optional(opts, key, conn) do
    if option(conn, key), do: Keyword.put(opts, key, option(conn, key)), else: opts
  end

  defp code_options_from_conn(conn) do
    with {:ok, params} <- Map.fetch(conn, :params),
	 {:ok, code} <- Map.fetch(params, "code") do
      [code: code]
    else
      _ -> []
    end
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
