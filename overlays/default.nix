# This file defines overlays
{inputs, ...}: let
  addPatches = pkg: patches: pkg.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ patches;
  });
in {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {pkgs = final;};

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
    pcmanfm = prev.pcmanfm.override { withGtk3 = true; };
    # add support for pangu markup to the hyprland/submaps module
    waybar = addPatches prev.waybar [ ./waybar.patch ];
    # change colorSchemeFromPicture backend from flavours to wpgtk
    # nix-colors = addPatches prev.nix-colors [ ./nix-colors-wpgtk.patch ];
    /*nix-colors = prev.nix-colors.overrideAttrs (old: {
      patches = (old.patches or []) ++ [ ./nix-colors-wpgtk.patch ];
    });*/
  };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
