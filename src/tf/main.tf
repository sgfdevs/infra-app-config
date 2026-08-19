module "openbao" {
  source = "./modules/openbao"
}

module "sgf_dev" {
  source = "./modules/sgf-dev"

  applications_mount_path      = module.openbao.applications_mount_path
  kubernetes_auth_backend_path = module.openbao.kubernetes_auth_backend_path
}

module "methodconf" {
  source = "./modules/methodconf"

  applications_mount_path      = module.openbao.applications_mount_path
  kubernetes_auth_backend_path = module.openbao.kubernetes_auth_backend_path
}

module "hack4goodsgf" {
  source = "./modules/hack4goodsgf"

  applications_mount_path      = module.openbao.applications_mount_path
  kubernetes_auth_backend_path = module.openbao.kubernetes_auth_backend_path
}

module "good_dads_enrollbot" {
  source = "./modules/good-dads-enrollbot"

  applications_mount_path      = module.openbao.applications_mount_path
  kubernetes_auth_backend_path = module.openbao.kubernetes_auth_backend_path
}

module "zitadel" {
  source = "./modules/zitadel"
}
