{
  description = "Netdata with login bypass patch";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          # Pre-fetch the dashboard since Nix sandbox has no network access
          dashboard = pkgs.fetchurl {
            url = "https://app.netdata.cloud/agent.tar.gz";
            hash = "sha256-CSu9s0iR6Ja7sMaabKum/7QU6NU1qYWhzhmTEZVVsyY=";
          };

          netdata-patched = pkgs.netdata.overrideAttrs (oldAttrs: {
            patches = (oldAttrs.patches or []) ++ [
              ./patches/bypass-login.patch
            ];

            # nixpkgs disables dashboard by default, we need to enable it
            cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
              "-DENABLE_DASHBOARD:BOOL=TRUE"
              "-DDASHBOARD_URL=file://${dashboard}"
            ];
          });

          entrypoint = pkgs.writeShellScript "netdata-entrypoint" ''
            # Create all required directories
            mkdir -p /var/log/netdata
            mkdir -p /var/lib/netdata
            mkdir -p /var/cache/netdata
            mkdir -p /var/run
            mkdir -p /etc/netdata
            mkdir -p /tmp
            chmod 1777 /tmp

            # -D: Don't fork (foreground)
            # -s /host: Use /host as system prefix for monitoring host from container
            exec ${netdata-patched}/bin/netdata -D -s /host "$@"
          '';
        in
        {
          netdata = netdata-patched;
          default = netdata-patched;

          docker = pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/vn7n24fzkq/netdata-standalone";
            tag = netdata-patched.version;

            contents = with pkgs; [
              netdata-patched
              bashInteractive
              coreutils
              procps
              gawk
              gnugrep
              findutils
              docker-client   # For Docker container monitoring
              dockerTools.fakeNss
            ];

            extraCommands = ''
              mkdir -p var/log/netdata
              mkdir -p var/lib/netdata
              mkdir -p var/cache/netdata
              mkdir -p var/run
              mkdir -p etc/netdata
              mkdir -p tmp
              chmod 1777 tmp
            '';

            config = {
              Cmd = [ "${entrypoint}" ];
              ExposedPorts = {
                "19999/tcp" = {};
              };
              Env = [
                "NETDATA_LISTENER_PORT=19999"
                "NETDATA_STOCK_CONFIG_DIR=${netdata-patched}/share/netdata/conf.d"
                "NETDATA_WEB_DIR=${netdata-patched}/share/netdata/web"
                "NETDATA_CACHE_DIR=/var/cache/netdata"
                "NETDATA_LIB_DIR=/var/lib/netdata"
                "NETDATA_LOG_DIR=/var/log/netdata"
                "NETDATA_LOCK_DIR=/var/lib/netdata/lock"
                "NETDATA_USER_CONFIG_DIR=/etc/netdata"
              ];
              WorkingDir = "/";
            };
          };
        }
      );

      overlays.default = final: prev: {
        netdata = self.packages.${prev.system}.netdata;
      };
    };
}
