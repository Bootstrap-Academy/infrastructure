{
  settings.global.excludes = [
    ".envrc"
    "*.md"
    "hosts/*/hardware-configuration.nix"
    "hosts/*/secrets.yml"
  ];

  programs.nixfmt.enable = true;
  programs.nixfmt.strict = true;

  programs.prettier.enable = true;
}
