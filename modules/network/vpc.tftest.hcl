mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "asia-northeast1"
}

run "network_uses_correct_name" {
  command = plan

  assert {
    condition     = google_compute_network.main.name == "overload-party-network"
    error_message = "Network name mismatch"
  }

  assert {
    condition     = google_compute_network.main.auto_create_subnetworks == false
    error_message = "auto_create_subnetworks should be false"
  }
}

run "subnet_uses_default_cidr" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.main.ip_cidr_range == "10.0.0.0/20"
    error_message = "Default CIDR should be 10.0.0.0/20"
  }
}

run "subnet_cidr_is_configurable" {
  command = plan

  variables {
    subnet_cidr = "10.1.0.0/20"
  }

  assert {
    condition     = google_compute_subnetwork.main.ip_cidr_range == "10.1.0.0/20"
    error_message = "Subnet CIDR should be configurable"
  }
}

run "private_ip_range_for_vpc_peering" {
  command = plan

  assert {
    condition     = google_compute_global_address.private_ip.purpose == "VPC_PEERING"
    error_message = "Private IP range purpose should be VPC_PEERING"
  }

  assert {
    condition     = google_compute_global_address.private_ip.address_type == "INTERNAL"
    error_message = "Address type should be INTERNAL"
  }
}
