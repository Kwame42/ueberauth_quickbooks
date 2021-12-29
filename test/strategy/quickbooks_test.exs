defmodule Ueberauth.Strategy.QuickBooksTest do
   use ExUnit.Case, async: true
   use Plug.Test

   import Mock
   import Plug.Conn
   import Ueberauth.Strategy.Helpers
   
   setup_with_mocks(
     [
       {OAuth2.Client,
        [:passthrough],
        [
   	 get_token: &oauth2_get_token/2,
   	 get: &oauth2_get/4
        ]
       }
     ]
   ) do
     # Create a connection with Ueberauth's CSRF cookies so they can be recycled during tests
     routes = Ueberauth.init([])
     csrf_conn = conn(:get, "/auth/quickbooks", %{}) |> Ueberauth.call(routes)
     csrf_state = with_state_param([], csrf_conn) |> Keyword.get(:state)
    
     {:ok, csrf_conn: csrf_conn, csrf_state: csrf_state}
   end

   def set_options(routes, conn, opt) do
     case Enum.find_index(routes, &(elem(&1, 0) == {conn.request_path, conn.method})) do
       nil -> routes
       idx -> update_in(routes, [Access.at(idx), Access.elem(1), Access.elem(2)], &%{&1 | options: opt})
     end
   end
   
   defp token(client, opts), do: {:ok, %{client | token: OAuth2.AccessToken.new(opts)}}
   defp response(body, code \\ 200), do: {:ok, %OAuth2.Response{status_code: code, body: body}}

   def oauth2_get_token(client, code: "success_code"), do: token(client, "success_token")
   def oauth2_get_token(client, code: "uid_code"), do: token(client, "uid_token")
   def oauth2_get_token(client, code: "userinfo_code"), do: token(client, "userinfo_token")

   def oauth2_get(%{token: %{access_token: "success_token"}}, _url, _, _),
     do: response(%{"sub" => "4242_loic", "name" => "Loic Monfort", "email" => "loic_monfort@breizh.bzh"})

   def oauth2_get(%{token: %{access_token: "uid_token"}}, _url, _, _),
     do: response(%{"uid_field" => "4242_arzhel", "name" => "Arzhel Le Goarant"})

   def oauth2_get(%{token: %{access_token: "userinfo_token"}}, "https://sandbox-accounts.platform.intuit.com/v1/openid_connect/userinfo", _, _),
     do: response(%{"sub" => "4242_antoine", "name" => "Antoine Engran"})

   def oauth2_get(%{token: %{access_token: "userinfo_token"}}, "example.com/soazig", _, _),
     do: response(%{"sub" => "4242_soazig", "name" => "Soazig Quemener"})

   def oauth2_get(%{token: %{access_token: "userinfo_token"}}, "example.com/goulwen", _, _),
     do: response(%{"sub" => "4242_goulwen", "name" => "Goulwen Blorec"})

   defp set_csrf_cookies(conn, csrf_conn) do
     conn
     |> init_test_session(%{})
     |> recycle_cookies(csrf_conn)
     |> fetch_cookies()
   end

   test "handle_request! redirects to appropriate auth uri" do
     conn = conn(:get, "/auth/quickbooks", %{})
    
    # Make sure the hd and scope params are included for good measure
     routes = Ueberauth.init() |> set_options(conn, hd: "example.com", default_scope: "email openid")

     resp = Ueberauth.call(conn, routes)
     assert resp.status == 302
     assert [location] = get_resp_header(resp, "location")

     redirect_uri = URI.parse(location)
     assert redirect_uri.host == "appcenter.intuit.com"
     assert redirect_uri.path == "/app/connect/oauth2"
     assert %{
             "client_id" => "client_id",
             "redirect_uri" => "http://www.example.com/auth/quickbooks/callback",
             "response_type" => "code",
             "scope" => "email openid",
             "hd" => "example.com"
     } = Plug.Conn.Query.decode(redirect_uri.query)
   end

   test "handle_callback! assigns required fields on successful auth", %{csrf_state: csrf_state, csrf_conn: csrf_conn} do
     conn =
       conn(:get, "/auth/quickbooks/callback", %{code: "success_code", state: csrf_state}) |> set_csrf_cookies(csrf_conn)
     
     routes = Ueberauth.init([])
     assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
     assert auth.credentials.token == "success_token"
     assert auth.info.name == "Loic Monfort"
     assert auth.info.email == "loic_monfort@breizh.bzh"
     assert auth.uid == "4242_loic"
   end

   test "uid_field is picked according to the specified option", %{csrf_state: csrf_state, csrf_conn: csrf_conn} do
     conn = conn(:get, "/auth/quickbooks/callback", %{code: "uid_code", state: csrf_state}) |> set_csrf_cookies(csrf_conn)
     routes = Ueberauth.init() |> set_options(conn, uid_field: "uid_field")
     assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
     assert auth.info.name == "Arzhel Le Goarant"
     assert auth.uid == "4242_arzhel"
   end

  test "userinfo is fetched according to userinfo_endpoint", %{csrf_state: csrf_state, csrf_conn: csrf_conn} do
    conn =
      conn(:get, "/auth/quickbooks/callback", %{code: "userinfo_code", state: csrf_state}) |> set_csrf_cookies(csrf_conn)

    routes = Ueberauth.init() |> set_options(conn, userinfo_endpoint: "example.com/soazig")
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.info.name == "Soazig Quemener"
  end

  test "userinfo can be set via runtime config with default", %{csrf_state: csrf_state, csrf_conn: csrf_conn} do
    conn =
      conn(:get, "/auth/quickbooks/callback", %{code: "userinfo_code", state: csrf_state}) |> set_csrf_cookies(csrf_conn)

    routes = Ueberauth.init() |> set_options(conn, userinfo_endpoint: {:system, "NOT_SET", "example.com/goulwen"})
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.info.name == "Goulwen Blorec"
  end

  test "userinfo uses default library value if runtime env not found", %{csrf_state: csrf_state, csrf_conn: csrf_conn} do
    conn =
      conn(:get, "/auth/quickbooks/callback", %{code: "userinfo_code", state: csrf_state}) |> set_csrf_cookies(csrf_conn)

    routes = Ueberauth.init() |> set_options(conn, userinfo_endpoint: {:system, "NOT_SET"})
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.info.name == "Antoine Engran"
  end

  test "userinfo can be set via runtime config", %{csrf_state: csrf_state, csrf_conn: csrf_conn} do
    conn =
      conn(:get, "/auth/quickbooks/callback", %{code: "userinfo_code", state: csrf_state}) |> set_csrf_cookies(csrf_conn)

    routes = Ueberauth.init() |> set_options(conn, userinfo_endpoint: {:system, "UEBERAUTH_GOULWEN"})
    System.put_env("UEBERAUTH_GOULWEN", "example.com/goulwen")
    assert %Plug.Conn{assigns: %{ueberauth_auth: auth}} = Ueberauth.call(conn, routes)
    assert auth.info.name == "Goulwen Blorec"
    System.delete_env("UEBERAUTH_GOULWEN")
  end

  test "state param is present in the redirect uri" do
    conn = conn(:get, "/auth/quickbooks", %{})

    routes = Ueberauth.init()
    resp = Ueberauth.call(conn, routes)

    assert [location] = get_resp_header(resp, "location")

    redirect_uri = URI.parse(location)

    assert redirect_uri.query =~ "state="
  end
end
