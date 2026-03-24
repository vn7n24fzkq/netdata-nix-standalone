# Netdata Nix Standalone

Netdata package with login bypass patch for NixOS.

This flake provides a patched version of Netdata that bypasses the cloud login requirement, allowing full dashboard access without signing in to Netdata Cloud.

## Why?

Netdata recently added a requirement to sign in to Netdata Cloud to access certain dashboard features. This patch removes that restriction for users who want to run Netdata locally without cloud integration.

Reference: [GitHub Discussion #17594](https://github.com/netdata/netdata/discussions/17594)

## Usage

### Build

```bash
nix build github:vn7n24fzkq/netdata-nix-standalone
```

### Install to user profile

```bash
nix profile install github:vn7n24fzkq/netdata-nix-standalone
```

### Use in NixOS (flake-based)

Add to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    netdata-custom = {
      url = "github:vn7n24fzkq/netdata-nix-standalone";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, netdata-custom, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          nixpkgs.overlays = [
            netdata-custom.overlays.default
          ];
        }
      ];
    };
  };
}
```

Then enable netdata in your `configuration.nix`:

```nix
{
  services.netdata.enable = true;
}
```

## Docker

### Quick Start with Docker Compose (Recommended)

```bash
# Download docker-compose.yml
curl -O https://raw.githubusercontent.com/vn7n24fzkq/netdata-nix-standalone/main/docker-compose.yml

# Start
docker compose up -d

# View logs
docker compose logs -f

# Stop
docker compose down
```

Optionally set a custom hostname:
```bash
NETDATA_HOSTNAME=my-server docker compose up -d
```

Then access the dashboard at http://localhost:19999

### Manual Docker Run

```bash
docker run -d \
  --name netdata \
  -p 19999:19999 \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  ghcr.io/vn7n24fzkq/netdata-standalone:latest
```

### Build Docker image locally

```bash
nix build .#docker
docker load < result
```

## CI/CD

This repository uses GitHub Actions for nightly builds:
- Runs daily at 00:00 UTC
- Builds and tests the Nix package
- Pushes Docker image to GitHub Container Registry
- Can be triggered manually via workflow dispatch

## Security Warning

This patch disables authentication checks. Make sure to:
- Use a reverse proxy with authentication, or
- Use SSH port forwarding, or
- Only expose Netdata on trusted networks

## License

The Netdata Agent is licensed under GPL-3.0. This patch is provided for personal use.
