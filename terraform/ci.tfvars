# CI-ONLY dummy values for the platform pipeline's OPA stage, which runs
# `terraform plan -var-file=ci.tfvars`. Nothing real or private here.
# Not auto-loaded by Terraform (unlike *.auto.tfvars), so real applies must
# still pass real values with -var.
allowed_ip              = "127.0.0.1/32"
eks_public_access_cidrs = ["127.0.0.1/32"]
