
variable "clusters" {
  description = "Cluster name overrides for the hub and each spoke"
  type = object({
    hub    = string
    spoke1 = string
    spoke2 = string
  })
  default = {
    hub    = "demo"
    spoke1 = "spoke-1"
    spoke2 = "spoke-2"
  }
}
