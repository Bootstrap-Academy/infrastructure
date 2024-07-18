{
  config,
  pkgs,
  lib,
  ...
}: let
  html = builtins.toFile "reset.html" ''
    <form method=post>
      <button name=user value=audi01>Reset audi01</button><br>
      <button name=user value=audi02>Reset audi02</button><br>
      <button name=user value=audi03>Reset audi03</button><br>
      <button name=user value=audi04>Reset audi04</button><br>
      <button name=user value=audi05>Reset audi05</button><br>
      <button name=user value=audi06>Reset audi06</button><br>
      <button name=user value=audi07>Reset audi07</button><br>
      <button name=user value=audi08>Reset audi08</button><br>
    </form>
  '';
  script = pkgs.writeShellScript "reset.sh" ''
    export PATH=${lib.makeBinPath ((with pkgs; [coreutils sudo]) ++ [config.services.postgresql.package])}

    sql() {
      sudo -u postgres psql "academy-$1" -tA <<< "$2"
    }

    reset() {
      if ! [[ "$1" =~ ^audi[0-9]+$ ]]; then return; fi
      id=$(sql auth "select id from auth_user where name='$1'")
      sql challenges "delete from challenges_coding_challenge_submissions where creator='$id';"
      sql challenges "delete from challenges_user_subtasks where user_id='$id';"
    EOF
    }

    echo Content-type: text/html
    echo

    user=$(cut -d= -f2-)
    if [[ -n "$user" ]]; then
      reset "$user" > /dev/null
      echo '<html><head><meta http-equiv="refresh" content="1; url=/reset" /></head><body>Resetting '"$user"'</body></html>'
    else
      cat ${html}
    fi
  '';
in {
  services.fcgiwrap.enable = true;
  services.nginx.virtualHosts."api.test.bootstrap.academy".locations."= /reset".extraConfig = ''
    auth_basic "Access restricted";
    auth_basic_user_file ${config.sops.secrets."reset/htpasswd".path};

    fastcgi_pass unix:${config.services.fcgiwrap.socketAddress};
    fastcgi_param SCRIPT_FILENAME ${script};
  '';

  sops.secrets."reset/htpasswd".owner = "nginx";
}
