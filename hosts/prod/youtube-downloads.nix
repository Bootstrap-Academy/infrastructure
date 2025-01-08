{nixpkgs-unstable, ...}: {
  imports = ["${nixpkgs-unstable}/nixos/modules/services/misc/ytdl-sub.nix"];

  services.sshfs.mounts."/mnt/youtube" = {
    host = "u381435.your-storagebox.de";
    port = 23;
    user = "u381435";
    path = "youtube";
    readOnly = false;
    allowOther = true;
  };

  services.ytdl-sub.instances.default = {
    enable = true;
    schedule = null; # TODO

    config = {
      presets."YouTube Playlist" = {
        preset = ["Max 480p"]; # TODO
        download = "{subscription_value}";
        output_options = {
          output_directory = "/mnt/youtube";
          file_name = "{subscription_name}/{playlist_index_padded}_{%sanitize(title)}.{ext}";
          maintain_download_archive = true;
        };
        ytdl_options = {
          cookiefile = "/var/lib/ytdl-sub/default/.cookies";
        };
      };
    };

    subscriptions."YouTube Playlist" = {
      rust = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7r4HuTyVCDLKlsD9EQzoncP";
      quantencomputer = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qS21FP5tk1QqmeAmd2hpQF";
      clean_code = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7ryyZikMDPxxyYxEKtKn0ji";
    };
  };

  systemd.services.ytdl-sub-default.serviceConfig.ReadWritePaths = ["/mnt/youtube"];
}
