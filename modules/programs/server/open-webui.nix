{
  config,
  pkgs,
  ...
}: {
  sops.secrets."open-webui/deepseek_api_key" = {};
  # kanidm-provision reads it to set the client's secret.
  sops.secrets."open-webui/oidc_client_secret" = {
    owner = "kanidm";
    restartUnits = ["kanidm.service"];
  };
  sops.secrets."open-webui/secret_key" = {};

  services.kanidm.provision = {
    groups.open-webui_users = {};
    systems.oauth2.open-webui = {
      basicSecretFile = config.sops.secrets."open-webui/oidc_client_secret".path;
      displayName = "Open WebUI";
      # Kanidm takes PNG, JPEG, GIF, SVG or WebP, up to 1024x1024 and 256 KiB.
      imageFile = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/open-webui/open-webui/v0.12.4/static/favicon.png";
        hash = "sha256-Vpij45UT57YwTslsMJNzqzrw9w/nlCk0Yd45WpTeqmU=";
      };
      originLanding = "https://ai.opena0.net";
      # Must match OPENID_REDIRECT_URI below.
      originUrl = "https://ai.opena0.net/oauth/oidc/callback";
      scopeMaps.open-webui_users = ["email" "openid" "profile"];
    };
  };

  # WEBUI_SECRET_KEY signs sessions and encrypts the stored OAuth tokens; left
  # unset, the image writes one into the data volume beside the database.
  sops.templates."open-webui.env" = {
    content = ''
      OAUTH_CLIENT_SECRET=${config.sops.placeholder."open-webui/oidc_client_secret"}
      OPENAI_API_KEY=${config.sops.placeholder."open-webui/deepseek_api_key"}
      WEBUI_SECRET_KEY=${config.sops.placeholder."open-webui/secret_key"}
    '';
    restartUnits = ["docker-open-webui.service"];
  };

  virtualisation.oci-containers.containers.open-webui = {
    image = "ghcr.io/open-webui/open-webui:v0.12.4";
    environment = {
      CORS_ALLOW_ORIGIN = "https://ai.opena0.net";
      ENABLE_COMMUNITY_SHARING = "false";
      ENABLE_LOGIN_FORM = "false";
      ENABLE_OAUTH_SIGNUP = "true";
      ENABLE_OLLAMA_API = "false";
      ENABLE_PASSWORD_AUTH = "false";
      # Settings come from here alone, so the API key is never copied into
      # webui.db. Admin-panel changes last only until the next restart.
      ENABLE_PERSISTENT_CONFIG = "false";
      ENABLE_SIGNUP = "false";
      # Diun watches for new releases.
      ENABLE_VERSION_UPDATE_CHECK = "false";
      # Kanidm refuses an authorization request without PKCE.
      OAUTH_CODE_CHALLENGE_METHOD = "S256";
      OAUTH_CLIENT_ID = "open-webui";
      OAUTH_PROVIDER_NAME = "Kanidm";
      OPENAI_API_BASE_URL = "https://api.deepseek.com/v1";
      OPENID_PROVIDER_URL = "https://idm.opena0.net/oauth2/openid/open-webui/.well-known/openid-configuration";
      OPENID_REDIRECT_URI = "https://ai.opena0.net/oauth/oidc/callback";
      WEBUI_SESSION_COOKIE_SECURE = "true";
      WEBUI_URL = "https://ai.opena0.net";
    };
    environmentFiles = [config.sops.templates."open-webui.env".path];
    volumes = ["open-webui_data:/app/backend/data"];
    networks = ["proxy"];
    labels = {
      caddy = "ai.opena0.net";
      "caddy.reverse_proxy" = "{{upstreams 8080}}";
    };
  };
}
