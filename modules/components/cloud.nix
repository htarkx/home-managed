# Cloud / provisioning CLIs. Each tool can be turned off on its own once the component is on.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.cloud;
  tool =
    desc:
    lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = desc;
    };
in
{
  options.my.cloud = {
    enable = lib.mkEnableOption "cloud / provisioning CLIs";
    gcloud = tool "google-cloud-sdk (~0.7 GiB, bundles its own Python)";
    ansible = tool "ansible-core (~0.65 GiB with the collections bundle)";
    kops = tool "kops (~0.25 GiB)";
    step = tool "step-cli";
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optional cfg.gcloud pkgs.google-cloud-sdk
      ++ lib.optional cfg.ansible pkgs.ansible
      ++ lib.optional cfg.kops pkgs.kops
      ++ lib.optional cfg.step pkgs.step-cli;
  };
}
