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
          netdata-patched = pkgs.netdata.overrideAttrs (oldAttrs: {
            patches = (oldAttrs.patches or []) ++ [
              ./patches/bypass-login.patch
            ];
          });
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
            ];

            config = {
              Cmd = [ "${netdata-patched}/bin/netdata" "-D" ];
              ExposedPorts = {
                "19999/tcp" = {};
              };
              Env = [
                "NETDATA_LISTENER_PORT=19999"
              ];
            };
          };
        }
      );

      overlays.default = final: prev: {
        netdata = self.packages.${prev.system}.netdata;
      };
    };
}
