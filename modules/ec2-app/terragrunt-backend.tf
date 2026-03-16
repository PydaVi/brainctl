terraform {
  # Necessário para que o remote_state do Terragrunt tenha efeito.
  backend "s3" {}
}
