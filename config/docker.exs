import Config

config :pleroma, Pleroma.Web.Endpoint,
  url: [host: System.get_env("DOMAINWEB", "localhost"), scheme: "https", port: 443],
  http: [ip: {0, 0, 0, 0}, port: System.get_env("PORT", "5000")]

config :pleroma, Pleroma.Web.WebFinger, domain: System.get_env("DOMAIN", "moeyy.cn")

config :pleroma, :instance,
  name: System.get_env("INSTANCE_NAME", "Soapbox"),
  email: System.get_env("ADMIN_EMAIL"),
  notify_email: System.get_env("NOTIFY_EMAIL"),
  limit: 5000,
  registrations_open: false,
  healthcheck: true

# Prefer `DATABASE_URL` if set, otherwise use granular env.
case System.get_env("DATABASE_URL") do
  database_url when is_binary(database_url) ->
    config :pleroma, Pleroma.Repo, url: database_url

  _ ->
    config :pleroma, Pleroma.Repo,
      username: System.get_env("DB_USER", "postgres"),
      password: System.get_env("DB_PASS", "postgres"),
      database: System.get_env("DB_NAME", "postgres"),
      hostname: System.get_env("DB_HOST", "db"),
      port: System.get_env("DB_PORT", "5432"),
      ssl: true,
      ssl_opts: [
        cacertfile: "/etc/ssl/certs/ca-certificates.crt",
        verify: :verify_none,
        #verify: :verify_peer,
        server_name_indication: to_charlist(System.get_env("DB_HOST", "db")),
        customize_hostname_check: [
        # By default, Erlang does not support wildcard certificates. This function supports validating wildcard hosts
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
    ]
  ]
end

# Configure web push notifications
config :web_push_encryption, :vapid_details, subject: "mailto:#{System.get_env("NOTIFY_EMAIL")}"

config :pleroma, :database, rum_enabled: false
config :pleroma, :instance, static_dir: "/var/lib/pleroma/static"
config :pleroma, Pleroma.Uploaders.Local, uploads: "/var/lib/pleroma/uploads"

config :pleroma, Pleroma.Language.LanguageDetector,
  provider: Pleroma.Language.LanguageDetector.Fasttext

config :pleroma, Pleroma.Language.LanguageDetector.Fasttext,
  model: "/usr/share/fasttext/lid.176.ftz"

# We can't store the secrets in this file, since this is baked into the docker image
if not File.exists?("/var/lib/pleroma/secret.exs") do
  secret = :crypto.strong_rand_bytes(64) |> Base.encode64() |> binary_part(0, 64)
  signing_salt = :crypto.strong_rand_bytes(8) |> Base.encode64() |> binary_part(0, 8)
  {web_push_public_key, web_push_private_key} = :crypto.generate_key(:ecdh, :prime256v1)

  secret_file =
    EEx.eval_string(
      """
      import Config

      config :pleroma, Pleroma.Web.Endpoint,
        secret_key_base: "<%= secret %>",
        signing_salt: "<%= signing_salt %>"

      config :web_push_encryption, :vapid_details,
        public_key: "<%= web_push_public_key %>",
        private_key: "<%= web_push_private_key %>"
      """,
      secret: secret,
      signing_salt: signing_salt,
      web_push_public_key: Base.url_encode64(web_push_public_key, padding: false),
      web_push_private_key: Base.url_encode64(web_push_private_key, padding: false)
    )

  File.write("/var/lib/pleroma/secret.exs", secret_file)
end

import_config("/var/lib/pleroma/secret.exs")

# For additional user config
if File.exists?("/var/lib/pleroma/config.exs"),
  do: import_config("/var/lib/pleroma/config.exs"),
  else:
    File.write("/var/lib/pleroma/config.exs", """
    import Config

    # For additional configuration outside of environmental variables
    """)
