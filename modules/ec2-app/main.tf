# TODO: módulo ec2-app v2. Este arquivo existe para definir o entrypoint do módulo.
# Ele é gerado como stub para evitar que times criem Terraform fora do padrão Terragrunt.

terraform {
  # Necessário para que o remote_state do Terragrunt tenha efeito.
  backend "s3" {}
}
