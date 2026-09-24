{ ... }:

{
  # Starship Prompt Engine (Liquid Glass Capsule Specification)
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      # Capsule layout: Pill 1 (User@Host) + Pill 2 (Folder) + Input chevron
      format = ''
[](#27272a)[ $username@$hostname ](bg:#27272a fg:#fafafa)[](#27272a) [](#18181b)[  $directory ](bg:#18181b fg:#f4f4f5)[](#18181b)$git_branch
$character'';

      add_newline = false;

      # Capsule 1: User & Host Identity
      username = {
        show_always = true;
        style_user = "bg:#27272a fg:#fafafa bold";
        format = "[$user]($style)";
      };

      hostname = {
        ssh_only = false;
        style = "bg:#27272a fg:#fafafa";
        format = "[$hostname]($style)";
      };

      # Capsule 2: Working Directory
      directory = {
        style = "bg:#18181b fg:#f4f4f5";
        format = "[$path]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
      };

      # Git Integration (Subtle Muted Zinc)
      git_branch = {
        style = "bg:#09090b fg:#71717a";
        format = " [](#09090b)[  $branch ]($style)[](#09090b)";
      };

      # Command Input Chevron (shadcn Zinc-500)
      character = {
        success_symbol = "[›](fg:#71717a) ";
        error_symbol = "[›](fg:#ef4444) ";
      };
    };
  };
}
