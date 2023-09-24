#############################################################################
#                 multiple Provider  Block                                                    
#############################################################################
provider "google" {
  credentials = file("key1.json")
  project     = "gke-demo-400007" #Project A
  region      = "us-central1"
}

provider "google" {

  project     = "diskreplication" # Project B
  region      = "us-central1"
  alias       = "gcp-service-project"
  credentials = file("key2.json")
}

#############################################################################
#             Create VPC/Subnet/Compute in First Project:  gke-demo-400007                                                  
#############################################################################

resource "google_compute_network" "vpc1" {
  name                    = "my-custom-network-1"
  auto_create_subnetworks = "false"

}

resource "google_compute_subnetwork" "my-custom-subnet1" {
  name          = "my-custom-subnet-1"
  ip_cidr_range = "10.255.196.0/24"
  network       = google_compute_network.vpc1.name
  region        = "us-central1"
}



resource "google_compute_instance" "my_vm" {
  project      = "gke-demo-400007"
  zone         = "us-central1-b"
  name         = "demo-1"
  machine_type = "e2-medium"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = "my-custom-network-1"
    subnetwork = google_compute_subnetwork.my-custom-subnet1.name # Replace with a reference or self link to your subnet, in quotes
  }
}


#############################################################################
#        Create second VPC/Subnet/compute in first Project:  gke-demo-400007                                                                  #
#############################################################################


resource "google_compute_network" "vpc2" {
  name                    = "my-custom-network-2"
  auto_create_subnetworks = "false"

}


resource "google_compute_subnetwork" "my-custom-subnet2" {
  name          = "my-custom-subnet-2"
  ip_cidr_range = "10.255.184.0/24"
  network       = google_compute_network.vpc2.name
  region        = "us-central1"

}


resource "google_compute_instance" "my_vm2" {
  project      = "gke-demo-400007"
  zone         = "us-central1-b"
  name         = "demo-2"
  machine_type = "e2-medium"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = "my-custom-network-2"
    subnetwork = google_compute_subnetwork.my-custom-subnet2.name # Replace with a reference or self link to your subnet, in quotes
  }
}

#############################################################################
#     Create third VPC/Subnet/compute in Second Project:  ServiceProjectA                                                                  #
#############################################################################


resource "google_compute_network" "vpc3" {
  name                    = "my-custom-network-3"
  provider                = google.gcp-service-project
  auto_create_subnetworks = "false"

}


resource "google_compute_subnetwork" "my-custom-subnet3" {
  name          = "my-custom-subnet-3"
  ip_cidr_range = "10.255.186.0/24"
  network       = google_compute_network.vpc3.name
  region        = "us-central1"
  provider      = google.gcp-service-project
}


resource "google_compute_instance" "my_vm3" {
  project      = "diskreplication"
  zone         = "us-central1-c"
  name         = "demo-3"
  machine_type = "e2-medium"
  provider     = google.gcp-service-project
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  network_interface {
    network    = "my-custom-network-3"
    subnetwork = google_compute_subnetwork.my-custom-subnet3.name # Replace with a reference or self link to your subnet, in quotes
  }
}



#############################################################################
#     Peering VPC1 <--> VPC2  and     VPC1 <--> VPC3                                                             #
#############################################################################

resource "google_compute_network_peering" "peering1" {
  name         = "peering1"
  network      = google_compute_network.vpc1.self_link
  peer_network = google_compute_network.vpc2.self_link
}

resource "google_compute_network_peering" "peering2" {
  name         = "peering2"
  network      = google_compute_network.vpc2.self_link
  peer_network = google_compute_network.vpc1.self_link
}

resource "google_compute_network_peering" "peering3" {
  name         = "peering3"
  network      = google_compute_network.vpc1.self_link
  peer_network = google_compute_network.vpc3.self_link
}

resource "google_compute_network_peering" "peering4" {
  name         = "peering4"
  provider     = google.gcp-service-project
  network      = google_compute_network.vpc3.self_link
  peer_network = google_compute_network.vpc1.self_link
}

#######################################################################################
#   Create firewalls for allow SSH from internet, allow icmp from VPC1 to VPC2 and VPC3
#######################################################################################

resource "google_compute_firewall" "rules" {
  project = "gke-demo-400007"
  name    = "allow-ssh"
  network = "my-custom-network-1" # Replace with a reference or self link to your network, in quotes

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}
##### create  Firewall to allow icmp from VPC1 to VPC2. such that on network VPC2
resource "google_compute_firewall" "allow-icmp-rule-vpc2" {
  project = "gke-demo-400007"
  name    = "allow-icmp"
  network = "my-custom-network-2" # Replace with a reference or self link to your network, in quotes

  allow {
    protocol = "icmp"

  }
  source_ranges = ["10.255.196.0/24"]
}


##### create  Firewall to allow icmp from VPC1 to VPC3. such that on network VPC3
resource "google_compute_firewall" "allow-icmp-rule-vpc3" {
  project  = "diskreplication"
  name     = "allow-icmp"
  network  = "my-custom-network-3" # Replace with a reference or self link to your network, in quotes
  provider = google.gcp-service-project

  allow {
    protocol = "icmp"

  }
  source_ranges = ["10.255.196.0/24"]
}


## Create IAP SSH permissions for your test instance

resource "google_project_iam_member" "project" {
  project = "gke-demo-400007"
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "serviceAccount:tf-sa-230@gke-demo-400007.iam.gserviceaccount.com"
}