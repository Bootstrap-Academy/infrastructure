{ sandkasten, ... }:

{
  imports = [ sandkasten.nixosModules.default ];

  services.sandkasten = {
    enable = true;

    environments = sandkastenPackages: sandkastenPackages.all;

    settings = {
      host = "0.0.0.0";
      port = 8000;

      enable_metrics = true;

      program_ttl = 300;
      prune_programs_interval = 60;

      max_concurrent_jobs = 2;

      base_resource_usage = {
        runs = 20;
        permits = 2;
      };

      compile_limits = {
        cpus = 1;
        time = 30; # seconds
        memory = 1024; # mb
        tmpfs = 256; # mb
        filesize = 16; # mb
        file_descriptors = 256;
        processes = 256;
        stdout_max_size = 65536;
        stderr_max_size = 65536;
        network = false;
      };
      run_limits = {
        cpus = 1;
        time = 5; # seconds
        memory = 512; # mb
        tmpfs = 256; # mb
        filesize = 16; # mb
        file_descriptors = 256;
        processes = 64;
        stdout_max_size = 65536;
        stderr_max_size = 65536;
        network = false;
      };
    };
  };
}
