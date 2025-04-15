variable "name" {
  description = "Name to give to the vm."
  type        = string
  default     = "minio"
}

variable "vcpus" {
  description = "Number of vcpus to assign to the vm"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Amount of memory in MiB"
  type        = number
  default     = 8192
}

variable "volume_id" {
  description = "Id of the disk volume to attach to the vm"
  type        = string
}

variable "minio_server" {
  type = object({
    tls         = object({
      server_cert = string
      server_key  = string
      ca_certs    = list(string)
    })
    auth        = object({
      root_username = string
      root_password = string
    })
    api_url     = string
    console_url = string
  })
}

variable "prometheus_auth_type" {
  description = "Authentication mode for prometheus scraping endpoints"
  type        = string
  default     = "jwt"
}

variable "godebug_settings" {
  description = "Comma-separated list of settings for environment variable GODEBUG"
  type        = string
  default     = ""
}

variable "sse" {
  type = object({
    enabled = bool
    server = object({
      tls          = object({
        client_cert = string
        client_key  = string
        server_cert = string
        server_key  = string
        ca_cert     = string
      })
      cache_expiry = optional(string, "10s")
      audit_logs   = optional(bool, false)
    })
    vault          = object({
      endpoint       = string
      mount          = string
      kv_version     = optional(string, "v1")
      prefix         = string
      approle        = object({
        mount          = string
        id             = string
        secret         = string
        retry_interval = optional(string, "10s")
      })
      ca_cert        = string
      ping_interval  = optional(string, "10s")
    })
  })
  default = {
    enabled = false
    server = {
      tls          = {
        client_cert = ""
        client_key  = ""
        server_cert = ""
        server_key  = ""
        ca_cert     = ""
      }
      cache_expiry = "10s"
      audit_logs   = false
    }
    vault          = {
      endpoint       = ""
      mount          = ""
      kv_version     = "v1"
      prefix         = ""
      approle        = {
        mount          = ""
        id             = ""
        secret         = ""
        retry_interval = "10s"
      }
      ca_cert        = ""
      ping_interval  = "10s"
    }
  }
}

variable "minio_os_uid" {
  description = "Uid that the minio os user will run as"
  type        = number
  default     = 999
}

variable "ferio" {
  type = object({
    etcd         = object({
      config_prefix      = string
      workspace_prefix   = string
      endpoints          = list(string)
      auth               = object({
        ca_cert       = string
        client_cert   = optional(string, "")
        client_key    = optional(string, "")
        username      = optional(string, "")
        password      = optional(string, "")
      })
    })
  })
  default = {
    etcd = {
      config_prefix      = ""
      workspace_prefix   = ""
      endpoints          = []
      auth               = {
        ca_cert       = ""
        client_cert   = ""
        client_key    = ""
        username      = ""
        password      = ""
      }
    }
  }
}

variable "server_pools" {
  type = list(object({
    domain_template     = string
    servers_count_begin = number
    servers_count_end   = number
    mount_path_template = string
    mounts_count        = number
  }))
  default = []

  validation {
    condition     = alltrue([for pool in var.server_pools: pool.domain_template != "" && pool.mount_path_template != ""])
    error_message = "Each entry in server_pools require that the following fields be non-empty strings: domain_template, mount_path_template"
  }

  validation {
    condition     = alltrue([for pool in var.server_pools: pool.servers_count_begin > 0 && pool.servers_count_end > 0 && pool.mounts_count > 0])
    error_message = "Each entry in server_pools require that the following fields be integers greater than 0: servers_count_begin, servers_count_end, mounts_count"
  }

  validation {
    condition     = alltrue([for pool in var.server_pools: pool.servers_count_begin <= pool.servers_count_end])
    error_message = "Each entry in server_pools require that the servers_count_begin field be less or equal to the servers_count_end field"
  }
}

variable "data_disks" {
  type = list(object({
    volume_id    = string
    block_device = string
    device_name  = string
    mount_label  = string
    mount_path   = string
  }))

  validation {
    condition     = alltrue([for vol in var.data_disks: vol.device_name != "" && vol.mount_label != "" && vol.mount_path != "" && ((vol.block_device != "" && vol.volume_id == "") || (vol.block_device == "" && vol.volume_id != ""))])
    error_message = "Each entry in data_disks must have the following keys defined and not empty: device_name, mount_label, mount_path, block_device xor volume_id"
  }
}

variable "minio_download_url" {
  type = string
  default = "https://dl.min.io/server/minio/release/linux-amd64/archive/minio.RELEASE.2023-12-23T07-19-11Z"
}

variable "libvirt_networks" {
  description = "Parameters of libvirt network connections if libvirt networks are used."
  type = list(object({
    network_name = optional(string, "")
    network_id = optional(string, "")
    prefix_length = string
    ip = string
    mac = string
    gateway = optional(string, "")
    dns_servers = optional(list(string), [])
  }))
  default = []

  validation {
    condition     = alltrue([for net in var.libvirt_networks: net.prefix_length != "" && net.ip != "" && net.mac != "" && ((net.network_name != "" && net.network_id == "") || (net.network_name == "" && net.network_id != ""))])
    error_message = "Each entry in libvirt_networks must have the following keys defined and not empty: prefix_length, ip, mac, network_name xor network_id"
  }
}

variable "macvtap_interfaces" {
  description = "List of macvtap interfaces."
  type        = list(object({
    interface     = string
    prefix_length = string
    ip            = string
    mac           = string
    gateway       = optional(string, "")
    dns_servers   = optional(list(string), [])
  }))
  default = []

  validation {
    condition     = alltrue([for int in var.macvtap_interfaces: int.interface != "" && int.prefix_length != "" && int.ip != "" && int.mac != ""])
    error_message = "Each entry in macvtap_interfaces must have the following keys defined and not empty: interface, prefix_length, ip, mac"
  }
}

variable "cloud_init_volume_pool" {
  description = "Name of the volume pool that will contain the cloud init volume"
  type        = string
}

variable "cloud_init_volume_name" {
  description = "Name of the cloud init volume"
  type        = string
  default     = ""
}

variable "ssh_admin_user" { 
  description = "Pre-existing ssh admin user of the image"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = var.ssh_admin_user != ""
    error_message = "ssh_admin_user must be defined and not be empty"
  }
}

variable "admin_user_password" { 
  description = "Optional password for admin user"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_admin_public_key" {
  description = "Public ssh part of the ssh key the admin will be able to login as"
  type        = string
}

variable "chrony" {
  description = "Chrony configuration for ntp. If enabled, chrony is installed and configured, else the default image ntp settings are kept"
  type        = object({
    enabled = bool,
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server
    servers = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool
    pools = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep
    makestep = object({
      threshold = number
      limit = number
    })
  })
  default = {
    enabled = false
    servers = []
    pools = []
    makestep = {
      threshold = 0
      limit = 0
    }
  }
}

variable "fluentbit" {
  description = "Fluent-bit configuration"
  type = object({
    enabled = bool
    minio_tag = string
    kes_tag = string
    ferio_tag = string
    node_exporter_tag = string
    metrics = optional(object({
      enabled = bool
      port    = number
    }), {
      enabled = false
      port = 0
    })
    forward = object({
      domain = string
      port = number
      hostname = string
      shared_key = string
      ca_cert = string
    })
  })
  default = {
    enabled = false
    minio_tag = ""
    kes_tag = ""
    ferio_tag = ""
    node_exporter_tag = ""
    metrics = {
      enabled = false
      port = 0
    }
    forward = {
      domain = ""
      port = 0
      hostname = ""
      shared_key = ""
      ca_cert = ""
    }
  }
}

variable "fluentbit_dynamic_config" {
  description = "Parameters for fluent-bit dynamic config if it is enabled"
  type = object({
    enabled = bool
    source  = string
    etcd    = optional(object({
      key_prefix     = string
      endpoints      = list(string)
      ca_certificate = string
      client         = object({
        certificate = string
        key         = string
        username    = string
        password    = string
      })
    }), {
      key_prefix     = ""
      endpoints      = []
      ca_certificate = ""
      client         = {
        certificate = ""
        key         = ""
        username    = ""
        password    = ""
      }
    })
    git     = optional(object({
      repo             = string
      ref              = string
      path             = string
      trusted_gpg_keys = list(string)
      auth             = object({
        client_ssh_key         = string
        client_ssh_user        = optional(string, "")
        server_ssh_fingerprint = string
      })
    }), {
      repo             = ""
      ref              = ""
      path             = ""
      trusted_gpg_keys = []
      auth             = {
        client_ssh_key         = ""
        client_ssh_user        = ""
        server_ssh_fingerprint = ""
      }
    })
  })
  default = {
    enabled = false
    source = "etcd"
    etcd = {
      key_prefix     = ""
      endpoints      = []
      ca_certificate = ""
      client         = {
        certificate = ""
        key         = ""
        username    = ""
        password    = ""
      }
    }
    git  = {
      repo             = ""
      ref              = ""
      path             = ""
      trusted_gpg_keys = []
      auth             = {
        client_ssh_key         = ""
        server_ssh_fingerprint = ""
      }
    }
  }

  validation {
    condition     = contains(["etcd", "git"], var.fluentbit_dynamic_config.source)
    error_message = "fluentbit_dynamic_config.source must be 'etcd' or 'git'."
  }
}

variable "install_dependencies" {
  description = "Whether to install all dependencies in cloud-init"
  type = bool
  default = true
}