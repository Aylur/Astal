{
  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];
  in {
    packages = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      mkPkg = src:
        import src {
          inherit self pkgs;
          mkAstalPkg = import ./nix/mkAstalPkg.nix pkgs;
        };
    in {
      default = self.packages.${system}.io;
      docs = import ./docs {inherit self pkgs;};

      io = mkPkg ./lib/astal/io;
      astal3 = mkPkg ./lib/astal/gtk3;
      astal4 = mkPkg ./lib/astal/gtk4;
      apps = mkPkg ./lib/apps;
      auth = mkPkg ./lib/auth;
      battery = mkPkg ./lib/battery;
      bluetooth = mkPkg ./lib/bluetooth;
      brightness = mkPkg ./lib/brightness;
      cava = mkPkg ./lib/cava;
      greet = mkPkg ./lib/greet;
      hyprland = mkPkg ./lib/hyprland;
      idle-notify = mkPkg ./lib/idle-notify;
      mpris = mkPkg ./lib/mpris;
      network = mkPkg ./lib/network;
      notifd = mkPkg ./lib/notifd;
      powerprofiles = mkPkg ./lib/powerprofiles;
      quarrel = mkPkg ./lib/quarrel;
      river = mkPkg ./lib/river;
      tray = mkPkg ./lib/tray;
      wireplumber = mkPkg ./lib/wireplumber;
      wl = mkPkg ./lib/wl/wl;
      workspace = mkPkg ./lib/workspace;
    });

    devShells = forAllSystems (system:
      import ./nix/devshell.nix {
        inherit self;
        pkgs = nixpkgs.legacyPackages.${system};
      });
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
}
