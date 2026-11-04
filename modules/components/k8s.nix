# Kubernetes clients. On Linux also helm, k9s and the k3s lifecycle shortcuts (scripts/k3s).
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.my.k8s;
  script = name: "bash ${config.my.repoPath}/scripts/k3s/${name}";
in
{
  options.my.k8s = {
    enable = lib.mkEnableOption "Kubernetes tools";
    cilium = lib.mkEnableOption "cilium-cli for the k3s + Cilium stack";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ pkgs.kubectl ] ++ lib.optional cfg.cilium pkgs.cilium-cli;
      }
      (lib.mkIf pkgs.stdenv.isLinux {
        home.packages = with pkgs; [
          kubernetes-helm
          k9s
        ];

        home.shellAliases = {
          k3s-install = script "k3s-install.sh";
          k3s-cilium = script "cilium-deploy.sh";
          k3s-monitoring = script "monitoring-deploy.sh";
          k3s-up = script "enable-all.sh";
          k3s-down = script "disable-all.sh";
          k3s-status = "kubectl get nodes && echo && kubectl get pods -A";
          k3s-monitoring-status = "helm status monitoring -n monitoring && echo && kubectl get pods -n monitoring";
          k3s-grafana-pass = "kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo";
          k3s-grafana = "kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80";
        };
      })
    ]
  );
}
