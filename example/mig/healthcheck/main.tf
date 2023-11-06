provider "google" {
  project = "opz0-397319"
  region  = "asia-northeast1"
  zone    = "asia-northeast1-a"
}

#####==============================================================================
##### vpc module call.
#####==============================================================================
module "vpc" {
  source                                    = "git::https://github.com/opz0/terraform-gcp-vpc.git?ref=v1.0.0"
  name                                      = "app"
  environment                               = "test"
  network_firewall_policy_enforcement_order = "AFTER_CLASSIC_FIREWALL"
}

#####==============================================================================
##### subnet module call.
#####==============================================================================
module "subnet" {
  source        = "git::https://github.com/opz0/terraform-gcp-subnet.git?ref=v1.0.0"
  name          = "subnet"
  environment   = "test"
  gcp_region    = "asia-northeast1"
  network       = module.vpc.vpc_id
  ip_cidr_range = "10.10.0.0/16"
}

#####==============================================================================
##### firewall module call.
#####==============================================================================
module "firewall" {
  source        = "git::https://github.com/opz0/terraform-gcp-firewall.git?ref=v1.0.0"
  name          = "app"
  environment   = "test"
  network       = module.vpc.vpc_id
  source_ranges = ["0.0.0.0/0"]

  allow = [
    { protocol = "tcp"
      ports    = ["22", "80"]
    }
  ]
}

#####==============================================================================
##### instance_template module call.
#####==============================================================================
module "instance_template" {
  source               = "git::https://github.com/opz0/terraform-gcp-template-instance.git?ref=v1.0.0"
  instance_template    = true
  name                 = "template"
  environment          = "test"
  region               = "asia-northeast1"
  source_image         = "ubuntu-2204-jammy-v20230908"
  source_image_family  = "ubuntu-2204-lts"
  source_image_project = "ubuntu-os-cloud"
  subnetwork           = module.subnet.subnet_id
  service_account      = null
  metadata = {
    ssh-keys = <<EOF
        dev:ssh-rsa +j/FmgC27u/+L6ihYrPhcx5/0YqTB2cIkD1/R0qwnOWlNBUpDL9//+/+//+51lj99yDW8X8W/+/+PDQMU= suresh@suresh
      EOF
  }
  access_config = [{
    nat_ip       = ""
    network_tier = ""
  }, ]
}

#####==============================================================================
##### instance_group module call.
#####==============================================================================
module "mig" {
  source              = "../../../"
  instance_template   = module.instance_template.self_link_unique
  region              = "asia-northeast1"
  autoscaling_enabled = true
  min_replicas        = 2
  hostname            = "test"
  environment         = "instance-group"

  autoscaling_cpu = [
    {
      target            = 0.4
      predictive_method = null
    },
  ]

  health_check = {
    type                = "https"
    initial_delay_sec   = 120
    check_interval_sec  = 5
    healthy_threshold   = 2
    timeout_sec         = 5
    unhealthy_threshold = 2
    response            = ""
    proxy_header        = "NONE"
    port                = 80
    request             = ""
    request_path        = "/"
    host                = "localhost"
    enable_logging      = false
  }
}