locals {
  cloud_init_volume_name = var.cloud_init_volume_name == "" ? "${var.name}-cloud-init.iso" : var.cloud_init_volume_name
  network_interfaces = concat(
    [for libvirt_network in var.libvirt_networks: {
      network_name = libvirt_network.network_name != "" ? libvirt_network.network_name : null
      network_id = libvirt_network.network_id != "" ? libvirt_network.network_id : null
      macvtap = null
      addresses = null
      mac = libvirt_network.mac
      hostname = null
    }],
    [for macvtap_interface in var.macvtap_interfaces: {
      network_name = null
      network_id = null
      macvtap = macvtap_interface.interface
      addresses = null
      mac = macvtap_interface.mac
      hostname = null
    }]
  )
  disks = concat(
    [{
      volume_id = var.volume_id
      block_device = null
    }], 
    [for disk in var.data_disks: {
      volume_id = disk.volume_id
      block_device = disk.block_device
    }]
  )
  fluentbit_updater_etcd = var.fluentbit.enabled && var.fluentbit_dynamic_config.enabled && var.fluentbit_dynamic_config.source == "etcd"
  fluentbit_updater_git = var.fluentbit.enabled && var.fluentbit_dynamic_config.enabled && var.fluentbit_dynamic_config.source == "git"
}

module "network_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//network?ref=v0.40.0"
  network_interfaces = concat(
    [for idx, libvirt_network in var.libvirt_networks: {
      ip = libvirt_network.ip
      gateway = libvirt_network.gateway
      prefix_length = libvirt_network.prefix_length
      interface = "libvirt${idx}"
      mac = libvirt_network.mac
      dns_servers = libvirt_network.dns_servers
    }],
    [for idx, macvtap_interface in var.macvtap_interfaces: {
      ip = macvtap_interface.ip
      gateway = macvtap_interface.gateway
      prefix_length = macvtap_interface.prefix_length
      interface = "macvtap${idx}"
      mac = macvtap_interface.mac
      dns_servers = macvtap_interface.dns_servers
    }]
  )
}

module "minio_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates//minio?ref=v0.40.0"
  install_dependencies = var.install_dependencies
  minio_server = {
    api_port          = 9000
    console_port      = 9001
    volumes_roots     = [for disk in var.data_disks: disk.mount_path]
    tls               = var.minio_server.tls
    auth              = var.minio_server.auth
    api_url           = var.minio_server.api_url
    console_url       = var.minio_server.console_url
  }
  kes = var.sse.enabled ? {
    endpoint = "127.0.0.1:7373"
    tls = {
      client_cert = var.sse.server.tls.client_cert
      client_key = var.sse.server.tls.client_key
      ca_cert = var.sse.server.tls.ca_cert
    }
    key = "minio"
  } : {
    endpoint = ""
    tls = {
      client_cert = ""
      client_key = ""
      ca_cert = ""
    }
    key = ""
  }
  prometheus_auth_type = var.prometheus_auth_type
  godebug_settings = var.godebug_settings
  minio_download_url = var.minio_download_url
  minio_os_uid = var.minio_os_uid
  volume_pools = var.server_pools
  setup_minio_service = !var.ferio.enabled
}

module "kes_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//minio-kes?ref=v0.40.0"
  install_dependencies = var.install_dependencies
  kes_server = {
    address      = "127.0.0.1"
    tls          = {
      server_cert = var.sse.server.tls.server_cert
      server_key  = var.sse.server.tls.server_key
      ca_cert     = var.sse.server.tls.ca_cert
    }
    clients      = [{
      name = "minio"
      key_prefix = "minio"
      permissions = {
        list_all = true
        create   = true
        delete   = false
        generate = true
        encrypt  = false
        decrypt  = true
      }
      client_cert = var.sse.server.tls.client_cert
    }]
    cache = {
      any    = var.sse.server.cache_expiry
      unused = var.sse.server.cache_expiry
    }
    audit_logs = var.sse.server.audit_logs
  }
  keystore = {
    vault = var.sse.vault
  }
}

module "ferio_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//ferio?ref=v0.40.0"
  install_dependencies = var.install_dependencies
  ferio = {
    etcd         = {
      config_prefix      = var.ferio.etcd.config_prefix
      workspace_prefix   = var.ferio.etcd.workspace_prefix
      endpoints          = var.ferio.etcd.endpoints
      connection_timeout = "60s"
      request_timeout    = "60s"
      retry_interval     = "4s"
      retries            = 15
      auth               = var.ferio.etcd.auth
    }
    host         = var.name
    log_level    = "info"
  }
  minio_os_uid = -1
}

module "prometheus_node_exporter_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//prometheus-node-exporter?ref=v0.40.0"
  install_dependencies = var.install_dependencies
}

module "chrony_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//chrony?ref=v0.40.0"
  install_dependencies = var.install_dependencies
  chrony = {
    servers  = var.chrony.servers
    pools    = var.chrony.pools
    makestep = var.chrony.makestep
  }
}

module "fluentbit_updater_etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//configurations-auto-updater?ref=v0.40.0"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = "/etc/fluent-bit-customization/dynamic-config"
    files_permission = "700"
    directories_permission = "700"
  }
  etcd = {
    key_prefix = var.fluentbit_dynamic_config.etcd.key_prefix
    endpoints = var.fluentbit_dynamic_config.etcd.endpoints
    connection_timeout = "60s"
    request_timeout = "60s"
    retry_interval = "4s"
    retries = 15
    auth = {
      ca_certificate = var.fluentbit_dynamic_config.etcd.ca_certificate
      client_certificate = var.fluentbit_dynamic_config.etcd.client.certificate
      client_key = var.fluentbit_dynamic_config.etcd.client.key
      username = var.fluentbit_dynamic_config.etcd.client.username
      password = var.fluentbit_dynamic_config.etcd.client.password
    }
  }
  notification_command = {
    command = ["/usr/local/bin/reload-fluent-bit-configs"]
    retries = 30
  }
  naming = {
    binary = "fluent-bit-config-updater"
    service = "fluent-bit-config-updater"
  }
  user = "fluentbit"
  vault_agent = {
    etcd_auth = {
      enabled = false
      secret_path = ""
    }
  }
}

module "fluentbit_updater_git_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//gitsync?ref=v0.40.0"
  install_dependencies = var.install_dependencies
  filesystem = {
    path = "/etc/fluent-bit-customization/dynamic-config"
    files_permission = "700"
    directories_permission = "700"
  }
  git = var.fluentbit_dynamic_config.git
  notification_command = {
    command = ["/usr/local/bin/reload-fluent-bit-configs"]
    retries = 30
  }
  naming = {
    binary = "fluent-bit-config-updater"
    service = "fluent-bit-config-updater"
  }
  user = "fluentbit"
}

module "fluentbit_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//fluent-bit?ref=v0.40.0"
  install_dependencies = var.install_dependencies
  fluentbit = {
    metrics = var.fluentbit.metrics
    systemd_services = concat([
      {
        tag     = var.fluentbit.minio_tag
        service = "minio.service"
      },
      {
        tag     = var.fluentbit.node_exporter_tag
        service = "node-exporter.service"
      }
    ],
    var.sse.enabled ? [{
      tag     = var.fluentbit.kes_tag
      service = "kes.service"
    }] : [],
    var.ferio.enabled ? [{
      tag     = var.fluentbit.ferio_tag 
      service = "ferio.service"
    }] : [])
    log_files = []
    forward = var.fluentbit.forward
  }
  dynamic_config = {
    enabled = var.fluentbit_dynamic_config.enabled
    entrypoint_path = "/etc/fluent-bit-customization/dynamic-config/index.conf"
  }
}

module "data_volume_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//data-volumes?ref=v0.40.0"
  volumes = [for idx, disk in var.data_disks: {
    label         = disk.mount_label
    device        = disk.device_name
    filesystem    = "xfs"
    mount_path    = disk.mount_path
    mount_options = "defaults"
  }]
}

locals {
  cloudinit_templates = concat([
      {
        filename     = "base.cfg"
        content_type = "text/cloud-config"
        content = templatefile(
          "${path.module}/files/user_data.yaml.tpl", 
          {
            hostname = var.name
            ssh_admin_public_key = var.ssh_admin_public_key
            ssh_admin_user = var.ssh_admin_user
            admin_user_password = var.admin_user_password
          }
        )
      },
      {
        filename     = "minio.cfg"
        content_type = "text/cloud-config"
        content      = module.minio_configs.configuration
      },
      {
        filename     = "node_exporter.cfg"
        content_type = "text/cloud-config"
        content      = module.prometheus_node_exporter_configs.configuration
      },
      {
        filename     = "data_volume.cfg"
        content_type = "text/cloud-config"
        content      = module.data_volume_configs.configuration
      }
    ],
    var.sse.enabled ? [{
      filename     = "kes.cfg"
      content_type = "text/cloud-config"
      content      = module.kes_configs.configuration
    }] : [],
    var.ferio.enabled ? [{
      filename     = "ferio.cfg"
      content_type = "text/cloud-config"
      content      = module.ferio_configs.configuration
    }] : [],
    var.chrony.enabled ? [{
      filename     = "chrony.cfg"
      content_type = "text/cloud-config"
      content      = module.chrony_configs.configuration
    }] : [],
    local.fluentbit_updater_etcd ? [{
      filename     = "fluent_bit_updater.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_updater_etcd_configs.configuration
    }] : [],
    local.fluentbit_updater_git ? [{
      filename     = "fluent_bit_updater.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_updater_git_configs.configuration
    }] : [],
    var.fluentbit.enabled ? [{
      filename     = "fluent_bit.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_configs.configuration
    }] : []
  )
}

data "template_cloudinit_config" "user_data" {
  gzip = false
  base64_encode = false
  dynamic "part" {
    for_each = local.cloudinit_templates
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

resource "libvirt_cloudinit_disk" "minio" {
  name           = local.cloud_init_volume_name
  user_data      = data.template_cloudinit_config.user_data.rendered
  network_config = module.network_configs.configuration
  pool           = var.cloud_init_volume_pool
}

resource "libvirt_domain" "minio" {
  name = var.name

  cpu {
    mode = "host-passthrough"
  }

  vcpu = var.vcpus
  memory = var.memory

  dynamic "disk" {
    for_each = local.disks
    content {
      volume_id = disk.value.volume_id
      block_device = disk.value.block_device
    }
  }

  dynamic "network_interface" {
    for_each = local.network_interfaces
    content {
      network_id = network_interface.value["network_id"]
      network_name = network_interface.value["network_name"]
      macvtap = network_interface.value["macvtap"]
      addresses = network_interface.value["addresses"]
      mac = network_interface.value["mac"]
      hostname = network_interface.value["hostname"]
    }
  }

  autostart = true

  cloudinit = libvirt_cloudinit_disk.minio.id

  //https://github.com/dmacvicar/terraform-provider-libvirt/blob/main/examples/v0.13/ubuntu/ubuntu-example.tf#L61
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
}