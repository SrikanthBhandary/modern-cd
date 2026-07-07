output "server" {
  value = data.external.cluster.result.server
}

output "token" {
  value = data.external.cluster.result.token
}

output "ca" {
  value = data.external.cluster.result.ca
}
