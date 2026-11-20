{
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
    schedule = "3/8:17";
    readWritePaths = [ "/mnt/youtube" ];

    config = {
      presets."YouTube Playlist" =
        let
          base_name = "{subscription_name}/{playlist_index_padded}_{uid}_{%sanitize(title)}";
        in
        {
          preset = [
            "Best Video Quality"
            "Chunk Downloads"
          ];
          download = "{subscription_value}";
          output_options = {
            output_directory = "/mnt/youtube";
            file_name = "${base_name}.{ext}";
            maintain_download_archive = true;
          };
          chapters = {
            embed_chapters = true;
            sponsorblock_categories = "all";
            remove_sponsorblock_categories = [
              "sponsor"
              "selfpromo"
              "interaction"
            ];
          };
          embed_thumbnail = true;
          subtitles = {
            subtitles_name = "${base_name}.{lang}.{subtitles_ext}";
            subtitles_type = "vtt";
            embed_subtitles = true;
            allow_auto_generated_subtitles = true;
            languages = [
              "en"
              "de"
            ];
          };
          ytdl_options = {
            cookiefile = "/var/lib/ytdl-sub/default/.cookies";
          };
          overrides = {
            chunk_max_downloads = 200;
          };
        };
    };

    subscriptions."YouTube Playlist" = {
      algorithmen_und_datenstrukturen = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7q2hZHyLJS6IeHQIlyEgKqf";
      angular_5 = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7pY65LXhI1_bIcOByRhP9Xb";
      anonymitaet_im_internet = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7on8Ckrk2wo4ySeenf3rgf0";
      assembler = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rhjy2t320NvKKGwP6Rxnpg";
      bash = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7r-Tw-cNntRgvwA7nXPAjP4";
      binaere_mathematik = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rsjQsc8hFAdR4BlO_MQib1";
      binary_exploitation_secure_coding = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qff-bnM05OqSI0fx4GknZ6";
      bitcoin_blockchain_kryptowaehrungen = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oiW2UVh1Go8JgllRbZRcPK";
      clean_code = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7ryyZikMDPxxyYxEKtKn0ji";
      cloud = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oxg9u5X2a-9X_jpN8iPOQy";
      cpp = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oG-kkn36ZnDpRq6iahUXZS";
      c_sharp = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rlNexPh8wjI2DyABX8It7U";
      css3_fuer_anfaenger = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qQz698kYRkkBXJDeXJY_I7";
      c = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7q4shI4L__SRpetWff9BjLZ";
      dart_flutter = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qokXX4II7FCZthJcrirT4o";
      data_mining = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qIOuGJrd-lu-ZZc9t4EdwM";
      datenvisualisierung = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7pb4apqIMKvCz37t_dLznMm";
      devops_grundlagen = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7pSbRnMtEG5XEdYVwJE5se9";
      docker = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oea6IDCLzpKe5XfLmWCwgr";
      firewalls = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oAAFVjNrAz1uRqIcanXreg";
      ghidra_reverse_engineering = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oQc3MxjWB-rYHHo9vX905a";
      git_und_github = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rbmmqb1Lt_RGU4DEhelTrR";
      graphentheorie = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7q2hZHyLJS6IeHQIlyEgKqf";
      haskell = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7pFIXDN1NLw6jMExuK-wN8I";
      html5_fuer_anfaenger = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qIbKPeroqn3-BkUTWzYBT4";
      iam = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rBqyMDGlv4LZmNrq1gChjh";
      it_sicherheit_hacken_essentials = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oVGaVtkLlu3jYl_D8ugxeT";
      java_algorithmen = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7o4qcD8tepVY5k7YiHYfMu5";
      java_fortgeschrittene_techniken = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oirQMpjPjrmNx4vcVIGIGY";
      java_ray_tracing = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rvhHip_LTM-J-5wHw7dWnw";
      javascript_express = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7ogA_q-mOoYH3dDQIh8B3Oe";
      javascript_jest = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qgQ2jnCFTo_knQTbpU5W4X";
      javascript = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qOfMI2ZNk-LXUAiXKrwDIi";
      java_swing = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7o5ALam15-pQWtf22RgU6D7";
      java = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qI9vtiiU5bJBfbxqBailVM";
      jquery = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qbE13388pQpsXQkpRQ96sM";
      kotlin_fortgeschrittene_techniken = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rylgyThgUldHG8KE6Nbc1O";
      kotlin = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rylgyThgUldHG8KE6Nbc1O";
      kryptographie = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7pWwFv5APk240hrehtCJae-";
      lambda_kalkuel = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oBz3PP5sGIkLnmBbw10UUP";
      latex = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7phxF5hBRWNJx9-KtIHjVYv";
      linux_autokey = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qCtvw6fiki0ihkwv7tIWN_";
      linux_distributionen = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7o15uBS2J9Ryz-pM-P9xcWJ";
      linux_gnupg = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7pUKpzMbzggvudByxULkut-";
      linux = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oaopPUB0SEmzZLf3aE5msy";
      llms = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7r4pg1j8eFsEQp3nL0w4jJz";
      logik = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7r7ztDWJ66pMNRYaa_TUjKP";
      machine_learning = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qoIUw0MBYQ9qJffZAVdRWC";
      medienkompetenz = "https://www.youtube.com/playlist?list=PL6RbeNL8jYDees12cwPupr49wMArrVQEX";
      mengenlehre = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7q_xBcMAlQ2K18HjMpAe0Nm";
      netzsicherheit = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7ovwsL-PKfByCX-jGuZAopM";
      netzwerktechnik = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rjW6OL4aGL-L1SzBUijh8r";
      nodejs = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7o-5JThNbEVW6CGAhWJwnkA";
      php_fuer_anfaenger = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rZMP1lj32Qyp4bkarvzCGm";
      programmieren_lernen = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7onyAB57T0xqV2ZVSZOo79a";
      prolog = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7q7ODiEAnq2EnsP-8LMGtfw";
      python_data_science = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7o46LI06XkxAqcg4Ucm7pwn";
      python_flask = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7otfP2zTa8AIiNIWVg0BRqs";
      python_lets_code = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7p09TLbRQmqzbH81DHjBO8E";
      python_pillow = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7p6tJ5S5Yvbw3reoZcHdyfR";
      python_pyqt = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7ruNQIfS8NRpjzZIRq0A8QP";
      python_pytorch = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rx55Mai21reZtd_8m-qe27";
      python_selenium = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7ruEf-FwVD3Z5owHgdXNKlb";
      python_tensorflow = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oj8ijyHSTOoW9bHLlXQ7hp";
      python = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7q0ao69AIogD94oBgp3E9Zs";
      react_js = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oi_Q4whC28Yp12l1I-hauk";
      sass_scss = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oopYYGy5hX-Y6b07_3DPp5";
      serveradministration = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7orIal3z8bq8HlHxnN-CtXr";
      signalverarbeitung = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qvLZlbEiRwHoP0mbmAHNId";
      softskills = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rC5g_bZNxZF6lOjSfNBKkE";
      softwareengineering = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qNMn6zimfu4JPUklG-4Uu4";
      spark_pyspark = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7pkk8-Yxa7mjAqi_E9DE_Z9";
      sql_und_datenbanken = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7qYPusTRflv3tkzhYoT-KiB";
      threejs = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rrmmZEVGA4GfLLNLlGipWo";
      typescript = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7pwHqtQSBXGBUNkyGGOJQXf";
      uml = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oC7U6tm0BOnGg1R9ont0Vo";
      unreal_engine = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7olLCliQ05e6hvEOl6sbBgv";
      windows10 = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7rRSgXNzZMV3XlrfklBugNW";
      wireshark = "https://www.youtube.com/playlist?list=PLNmsVeXQZj7oIlWv3K9xACZi3fHfYLKtj";

      # TODO
      # lustige_web_ui_effekte = "";
    };
  };
}
