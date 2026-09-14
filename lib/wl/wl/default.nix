{
  mkAstalPkg,
  pkgs,
  ...
}: let
  wl-vapi-gen = pkgs.stdenv.mkDerivation {
    pname = "wl-vapi-gen";
    version = "v1.0.0";
    src = pkgs.fetchFromGitHub {
      owner = "kotontrion";
      repo = "wl-vapi-gen";
      rev = "1.0.0";
      hash = "sha256-XdgYmxW0ndH6szq7VJ+XQEnWKHCyaWoBwEQREZnTm98=";
    };

    nativeBuildInputs = with pkgs; [
      meson
      ninja
      python3
    ];

    patchPhase = ''
      patchShebangs wl-vapi-gen.py
    '';
  };
in
  mkAstalPkg {
    pname = "astal-wl";
    src = ./.;
    packages = [wl-vapi-gen];

    libname = "wl";
    authors = "kotontrion";
    name = "AstalWl";
    description = "A central wayland connection manager for the other libs.";
  }
