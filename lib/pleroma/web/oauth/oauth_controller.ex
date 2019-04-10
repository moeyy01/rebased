# Pleroma: A lightweight social networking server
# Copyright © 2017-2019 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.OAuth.OAuthController do
  use Pleroma.Web, :controller

  alias Pleroma.Registration
  alias Pleroma.Repo
  alias Pleroma.User
  alias Pleroma.Web.Auth.Authenticator
  alias Pleroma.Web.ControllerHelper
  alias Pleroma.Web.OAuth.App
  alias Pleroma.Web.OAuth.Authorization
  alias Pleroma.Web.OAuth.Token

  import Pleroma.Web.ControllerHelper, only: [oauth_scopes: 2]

  if Pleroma.Config.oauth_consumer_enabled?(), do: plug(Ueberauth)

  plug(:fetch_session)
  plug(:fetch_flash)

  action_fallback(Pleroma.Web.OAuth.FallbackController)

  def authorize(%{assigns: %{token: %Token{} = token}} = conn, params) do
    if ControllerHelper.truthy_param?(params["force_login"]) do
      do_authorize(conn, params)
    else
      redirect_uri =
        if is_binary(params["redirect_uri"]) do
          params["redirect_uri"]
        else
          app = Repo.preload(token, :app).app

          app.redirect_uris
          |> String.split()
          |> Enum.at(0)
        end

      redirect(conn, external: redirect_uri(conn, redirect_uri))
    end
  end

  def authorize(conn, params), do: do_authorize(conn, params)

  defp do_authorize(conn, %{"authorization" => auth_attrs}) do
    app = Repo.get_by(App, client_id: auth_attrs["client_id"])
    available_scopes = (app && app.scopes) || []
    scopes = oauth_scopes(auth_attrs, nil) || available_scopes

    render(conn, Authenticator.auth_template(), %{
      response_type: auth_attrs["response_type"],
      client_id: auth_attrs["client_id"],
      available_scopes: available_scopes,
      scopes: scopes,
      redirect_uri: auth_attrs["redirect_uri"],
      state: auth_attrs["state"],
      params: auth_attrs
    })
  end

  defp do_authorize(conn, auth_attrs), do: do_authorize(conn, %{"authorization" => auth_attrs})

  def create_authorization(
        conn,
        %{"authorization" => _} = params,
        opts \\ []
      ) do
    with {:ok, auth} <- do_create_authorization(conn, params, opts[:user]) do
      after_create_authorization(conn, auth, params)
    else
      error ->
        handle_create_authorization_error(conn, error, params)
    end
  end

  def after_create_authorization(conn, auth, %{
        "authorization" => %{"redirect_uri" => redirect_uri} = auth_attrs
      }) do
    redirect_uri = redirect_uri(conn, redirect_uri)

    if redirect_uri == "urn:ietf:wg:oauth:2.0:oob" do
      render(conn, "results.html", %{
        auth: auth
      })
    else
      connector = if String.contains?(redirect_uri, "?"), do: "&", else: "?"
      url = "#{redirect_uri}#{connector}"
      url_params = %{:code => auth.token}

      url_params =
        if auth_attrs["state"] do
          Map.put(url_params, :state, auth_attrs["state"])
        else
          url_params
        end

      url = "#{url}#{Plug.Conn.Query.encode(url_params)}"

      redirect(conn, external: url)
    end
  end

  defp handle_create_authorization_error(
         conn,
         {scopes_issue, _},
         %{"authorization" => _} = params
       )
       when scopes_issue in [:unsupported_scopes, :missing_scopes] do
    # Per https://github.com/tootsuite/mastodon/blob/
    #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L39
    conn
    |> put_flash(:error, "This action is outside the authorized scopes")
    |> put_status(:unauthorized)
    |> authorize(params)
  end

  defp handle_create_authorization_error(
         conn,
         {:auth_active, false},
         %{"authorization" => _} = params
       ) do
    # Per https://github.com/tootsuite/mastodon/blob/
    #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L76
    conn
    |> put_flash(:error, "Your login is missing a confirmed e-mail address")
    |> put_status(:forbidden)
    |> authorize(params)
  end

  defp handle_create_authorization_error(conn, error, %{"authorization" => _}) do
    Authenticator.handle_error(conn, error)
  end

  def token_exchange(conn, %{"grant_type" => "authorization_code"} = params) do
    with %App{} = app <- get_app_from_request(conn, params),
         fixed_token = fix_padding(params["code"]),
         %Authorization{} = auth <-
           Repo.get_by(Authorization, token: fixed_token, app_id: app.id),
         %User{} = user <- User.get_by_id(auth.user_id),
         {:ok, token} <- Token.exchange_token(app, auth),
         {:ok, inserted_at} <- DateTime.from_naive(token.inserted_at, "Etc/UTC") do
      response = %{
        token_type: "Bearer",
        access_token: token.token,
        refresh_token: token.refresh_token,
        created_at: DateTime.to_unix(inserted_at),
        expires_in: 60 * 10,
        scope: Enum.join(token.scopes, " "),
        me: user.ap_id
      }

      json(conn, response)
    else
      _error ->
        put_status(conn, 400)
        |> json(%{error: "Invalid credentials"})
    end
  end

  def token_exchange(
        conn,
        %{"grant_type" => "password"} = params
      ) do
    with {_, {:ok, %User{} = user}} <- {:get_user, Authenticator.get_user(conn)},
         %App{} = app <- get_app_from_request(conn, params),
         {:auth_active, true} <- {:auth_active, User.auth_active?(user)},
         {:user_active, true} <- {:user_active, !user.info.deactivated},
         scopes <- oauth_scopes(params, app.scopes),
         [] <- scopes -- app.scopes,
         true <- Enum.any?(scopes),
         {:ok, auth} <- Authorization.create_authorization(app, user, scopes),
         {:ok, token} <- Token.exchange_token(app, auth) do
      response = %{
        token_type: "Bearer",
        access_token: token.token,
        refresh_token: token.refresh_token,
        expires_in: 60 * 10,
        scope: Enum.join(token.scopes, " "),
        me: user.ap_id
      }

      json(conn, response)
    else
      {:auth_active, false} ->
        # Per https://github.com/tootsuite/mastodon/blob/
        #   51e154f5e87968d6bb115e053689767ab33e80cd/app/controllers/api/base_controller.rb#L76
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Your login is missing a confirmed e-mail address"})

      {:user_active, false} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Your account is currently disabled"})

      _error ->
        put_status(conn, 400)
        |> json(%{error: "Invalid credentials"})
    end
  end

  def token_exchange(
        conn,
        %{"grant_type" => "password", "name" => name, "password" => _password} = params
      ) do
    params =
      params
      |> Map.delete("name")
      |> Map.put("username", name)

    token_exchange(conn, params)
  end

  def token_revoke(conn, %{"token" => token} = params) do
    with %App{} = app <- get_app_from_request(conn, params),
         %Token{} = token <- Repo.get_by(Token, token: token, app_id: app.id),
         {:ok, %Token{}} <- Repo.delete(token) do
      json(conn, %{})
    else
      _error ->
        # RFC 7009: invalid tokens [in the request] do not cause an error response
        json(conn, %{})
    end
  end

  @doc "Prepares OAuth request to provider for Ueberauth"
  def prepare_request(conn, %{"provider" => provider, "authorization" => auth_attrs}) do
    scope =
      oauth_scopes(auth_attrs, [])
      |> Enum.join(" ")

    state =
      auth_attrs
      |> Map.delete("scopes")
      |> Map.put("scope", scope)
      |> Poison.encode!()

    params =
      auth_attrs
      |> Map.drop(~w(scope scopes client_id redirect_uri))
      |> Map.put("state", state)

    # Handing the request to Ueberauth
    redirect(conn, to: o_auth_path(conn, :request, provider, params))
  end

  def request(conn, params) do
    message =
      if params["provider"] do
        "Unsupported OAuth provider: #{params["provider"]}."
      else
        "Bad OAuth request."
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, params) do
    params = callback_params(params)
    messages = for e <- Map.get(failure, :errors, []), do: e.message
    message = Enum.join(messages, "; ")

    conn
    |> put_flash(:error, "Failed to authenticate: #{message}.")
    |> redirect(external: redirect_uri(conn, params["redirect_uri"]))
  end

  def callback(conn, params) do
    params = callback_params(params)

    with {:ok, registration} <- Authenticator.get_registration(conn) do
      user = Repo.preload(registration, :user).user
      auth_attrs = Map.take(params, ~w(client_id redirect_uri scope scopes state))

      if user do
        create_authorization(
          conn,
          %{"authorization" => auth_attrs},
          user: user
        )
      else
        registration_params =
          Map.merge(auth_attrs, %{
            "nickname" => Registration.nickname(registration),
            "email" => Registration.email(registration)
          })

        conn
        |> put_session(:registration_id, registration.id)
        |> registration_details(%{"authorization" => registration_params})
      end
    else
      _ ->
        conn
        |> put_flash(:error, "Failed to set up user account.")
        |> redirect(external: redirect_uri(conn, params["redirect_uri"]))
    end
  end

  defp callback_params(%{"state" => state} = params) do
    Map.merge(params, Poison.decode!(state))
  end

  def registration_details(conn, %{"authorization" => auth_attrs}) do
    render(conn, "register.html", %{
      client_id: auth_attrs["client_id"],
      redirect_uri: auth_attrs["redirect_uri"],
      state: auth_attrs["state"],
      scopes: oauth_scopes(auth_attrs, []),
      nickname: auth_attrs["nickname"],
      email: auth_attrs["email"]
    })
  end

  def register(conn, %{"authorization" => _, "op" => "connect"} = params) do
    with registration_id when not is_nil(registration_id) <- get_session_registration_id(conn),
         %Registration{} = registration <- Repo.get(Registration, registration_id),
         {_, {:ok, auth}} <-
           {:create_authorization, do_create_authorization(conn, params)},
         %User{} = user <- Repo.preload(auth, :user).user,
         {:ok, _updated_registration} <- Registration.bind_to_user(registration, user) do
      conn
      |> put_session_registration_id(nil)
      |> after_create_authorization(auth, params)
    else
      {:create_authorization, error} ->
        {:register, handle_create_authorization_error(conn, error, params)}

      _ ->
        {:register, :generic_error}
    end
  end

  def register(conn, %{"authorization" => _, "op" => "register"} = params) do
    with registration_id when not is_nil(registration_id) <- get_session_registration_id(conn),
         %Registration{} = registration <- Repo.get(Registration, registration_id),
         {:ok, user} <- Authenticator.create_from_registration(conn, registration) do
      conn
      |> put_session_registration_id(nil)
      |> create_authorization(
        params,
        user: user
      )
    else
      {:error, changeset} ->
        message =
          Enum.map(changeset.errors, fn {field, {error, _}} ->
            "#{field} #{error}"
          end)
          |> Enum.join("; ")

        message =
          String.replace(
            message,
            "ap_id has already been taken",
            "nickname has already been taken"
          )

        conn
        |> put_status(:forbidden)
        |> put_flash(:error, "Error: #{message}.")
        |> registration_details(params)

      _ ->
        {:register, :generic_error}
    end
  end

  defp do_create_authorization(
         conn,
         %{
           "authorization" =>
             %{
               "client_id" => client_id,
               "redirect_uri" => redirect_uri
             } = auth_attrs
         },
         user \\ nil
       ) do
    with {_, {:ok, %User{} = user}} <-
           {:get_user, (user && {:ok, user}) || Authenticator.get_user(conn)},
         %App{} = app <- Repo.get_by(App, client_id: client_id),
         true <- redirect_uri in String.split(app.redirect_uris),
         scopes <- oauth_scopes(auth_attrs, []),
         {:unsupported_scopes, []} <- {:unsupported_scopes, scopes -- app.scopes},
         # Note: `scope` param is intentionally not optional in this context
         {:missing_scopes, false} <- {:missing_scopes, scopes == []},
         {:auth_active, true} <- {:auth_active, User.auth_active?(user)} do
      Authorization.create_authorization(app, user, scopes)
    end
  end

  # XXX - for whatever reason our token arrives urlencoded, but Plug.Conn should be
  # decoding it.  Investigate sometime.
  defp fix_padding(token) do
    token
    |> URI.decode()
    |> Base.url_decode64!(padding: false)
    |> Base.url_encode64(padding: false)
  end

  defp get_app_from_request(conn, params) do
    # Per RFC 6749, HTTP Basic is preferred to body params
    {client_id, client_secret} =
      with ["Basic " <> encoded] <- get_req_header(conn, "authorization"),
           {:ok, decoded} <- Base.decode64(encoded),
           [id, secret] <-
             String.split(decoded, ":")
             |> Enum.map(fn s -> URI.decode_www_form(s) end) do
        {id, secret}
      else
        _ -> {params["client_id"], params["client_secret"]}
      end

    if client_id && client_secret do
      Repo.get_by(
        App,
        client_id: client_id,
        client_secret: client_secret
      )
    else
      nil
    end
  end

  # Special case: Local MastodonFE
  defp redirect_uri(conn, "."), do: mastodon_api_url(conn, :login)

  defp redirect_uri(_conn, redirect_uri), do: redirect_uri

  defp get_session_registration_id(conn), do: get_session(conn, :registration_id)

  defp put_session_registration_id(conn, registration_id),
    do: put_session(conn, :registration_id, registration_id)
end
