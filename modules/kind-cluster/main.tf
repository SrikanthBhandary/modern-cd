resource "null_resource" "kind_cluster" {
  triggers = {
    cluster_name = var.cluster_name
    config_hash  = filesha256(var.config_file)
  }

  provisioner "local-exec" {
    command = "kind create cluster --name ${self.triggers.cluster_name} --config ${var.config_file}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name ${self.triggers.cluster_name}"
  }
}