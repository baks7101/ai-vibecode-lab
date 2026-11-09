# ---------------------------------------------------------------------
# Amazon VPC CNI, managed by Terraform
#
# Without this resource, EKS installs the VPC CNI with AWS's stock
# settings, where network policy enforcement is OFF. Kubernetes would
# then accept NetworkPolicy objects but nothing would enforce them:
# a control that looks active but does nothing.
#
# Managing the add-on here puts the setting in code: reviewed in a PR,
# scanned by the pipeline, and identical on every rebuild.
# ---------------------------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  # Pinned, not floating: every rebuild gets the version we tested.
  # Network policy support needs v1.14+. Bump deliberately, via a PR.
  addon_version = var.vpc_cni_version

  # EKS already installs a stock VPC CNI when the cluster is created.
  # OVERWRITE lets Terraform take ownership of it and apply our settings,
  # instead of failing because the add-on "already exists".
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Switches on the network policy agent that runs alongside the CNI on
  # every node and enforces NetworkPolicy objects using eBPF.
  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })
}
