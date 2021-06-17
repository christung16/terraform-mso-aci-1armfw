# AUTHOR(s): Chris Tung <yitung@cisco.com>

terraform {
  required_providers {
    mso = {
      source = "CiscoDevNet/mso"
      version = "0.1.5"
    }
    aci = {
      source = "CiscoDevNet/aci"
      version = "0.7.0"
    }
    vsphere = {
      source = "hashicorp/vsphere"
      version = "1.26.0"
    }
  }
}

provider "mso" {
  username = var.mso_user.username
  password = var.mso_user.password
  url      = var.mso_user.url
  insecure = true
}

provider "aci" {
  username = var.aci_user.username
  password = var.aci_user.password
  url = var.aci_user.url
  insecure = true
}

provider "vsphere" {
  user = var.vcenter_user.username
  password = var.vcenter_user.password
  vsphere_server = var.vcenter_user.url
  allow_unverified_ssl = true
}


resource "aci_vlan_pool" "vlan_pool" {
  for_each = var.vlan_pool
  name = each.value.name
  alloc_mode = each.value.alloc_mode
}

resource "aci_ranges" "vlan_range" {
  for_each = var.vlan_pool
  vlan_pool_dn = aci_vlan_pool.vlan_pool[each.value.name].id
  from = each.value.from
  to = each.value.to
}

resource "aci_attachable_access_entity_profile" "vmm_vmware_aaep" {
  for_each = var.vmm_vmware
  name = each.value.aaep_name
#  relation_infra_rs_dom_p = [format ( "%s%s%s", each.value.provider_profile_dn,"/dom-",each.value.name )]
  relation_infra_rs_dom_p = [ aci_vmm_domain.vmm_domain[each.value.name].id ]
#  depends_on = [
#    aci_vmm_domain.vmm_domain,
#  ]
}

resource "aci_vmm_domain" "vmm_domain" {
  for_each = var.vmm_vmware
  provider_profile_dn = each.value.provider_profile_dn
  name = each.value.name
#  relation_infra_rs_vlan_ns = format( "%s%s%s", "uni/infra/vlanns-[", each.value.vlan_pool,"]-dynamic")
  relation_infra_rs_vlan_ns = aci_vlan_pool.vlan_pool[each.value.vlan_pool].id
}

resource "aci_vmm_credential" "vmm_cred" {
  for_each = var.vmm_vmware
  vmm_domain_dn = aci_vmm_domain.vmm_domain[each.value.name].id
  name = format( "%s%s", each.value.name,"-credential")
  annotation = "orchestrator:terraform"
  pwd = each.value.vcenter_pwd
  usr = each.value.vcenter_usr
}

resource "aci_vmm_controller" "gen_com_ctrl" {
  for_each = var.vmm_vmware
  vmm_domain_dn = aci_vmm_domain.vmm_domain[each.value.name].id
  name = format( "%s%s", each.value.name,"-controller")
  host_or_ip = each.value.vcenter_host_or_ip
  root_cont_name = each.value.vcenter_datacenter_name
  dvs_version = each.value.dvs_version
#  relation_vmm_rs_acc = format ( "%s%s%s%s%s", "uni/vmmp-VMware/dom-",each.value.name,"/usracc-",each.value.name,"-credential")
  relation_vmm_rs_acc = aci_vmm_credential.vmm_cred[each.value.name].id
}

resource "aci_attachable_access_entity_profile" "phydomain_aaep" {
  for_each = var.phydomain
  name = each.value.aaep_name
  relation_infra_rs_dom_p = [ aci_physical_domain.phydom[each.value.name].id ]
}


resource "aci_physical_domain" "phydom" {
  for_each = var.phydomain
  name = each.value.name
  relation_infra_rs_vlan_ns = aci_vlan_pool.vlan_pool[each.value.vlan_pool].id
}

resource "aci_cdp_interface_policy" "cdp" {
  for_each = var.cdp
  name = each.value.name
  admin_st = each.value.admin_st
}

resource "aci_lldp_interface_policy" "lldp" {
  for_each = var.lldp
  name = each.value.name
  description = each.value.description
  admin_tx_st = each.value.admin_tx_st
  admin_rx_st = each.value.admin_rx_st
}

module "accessportgroup" {
  source = "../modules/accessportgroup"
  for_each = var.access_port_group_policy
  name = each.value.name
  lldp_status = each.value.lldp_status
  cdp_status  = each.value.cdp_status
  aaep_name = each.value.aaep_name
  leaf_profile = each.value.leaf_profile
  leaf_block = each.value.leaf_block
  from_card = each.value.from_card
  from_port = each.value.from_port
  to_card = each.value.to_card
  to_port = each.value.to_port
  depends_on = [
    aci_cdp_interface_policy.cdp,
    aci_lldp_interface_policy.lldp,
#    aci_lacp_policy.lacp,
    aci_attachable_access_entity_profile.vmm_vmware_aaep,
    aci_attachable_access_entity_profile.phydomain_aaep,
  ]
}


data "mso_site" "site1" {
  name = var.mso_site
}

locals {
  bd_subnets = flatten ([
    for bd_key, bd in var.bds : [
      for subnet in bd.subnets : {
        bd_name = bd_key
        bd_subnet = subnet
        
      }
    ]
  ])
}

/*
output "flatten_bd" {
  value = local.bd_subnets
}

output "flatten_l3out" {
  value = local.l3out_subnets
}
*/

resource "mso_tenant" "tn" {
    name = var.tenant.name
    display_name = var.tenant.name
    description = var.tenant.description
    site_associations {
      site_id = data.mso_site.site1.id
    }
}

resource "mso_schema" "schema" {
  name = var.schema_name
  template_name = var.template_name
  tenant_id = mso_tenant.tn.id
  depends_on = [
#    mso_tenant.tn,
    aci_vmm_domain.vmm_domain,
  ]
}

resource "mso_schema_site" "schema_site1" {
  schema_id = mso_schema.schema.id
  site_id = data.mso_site.site1.id
  template_name = mso_schema.schema.template_name
#  depends_on = [
#    mso_schema.schema,
#  ]
}

resource "mso_schema_template_vrf" "vrfs" {
  for_each = var.vrfs
  name = each.value.name
  schema_id = mso_schema.schema.id
#  template = mso_schema.schema.template_name
  template = mso_schema.schema.template_name
  display_name = each.value.display_name
  layer3_multicast = false
  vzany = false
#  depends_on = [
#    mso_schema.schema
#  ]
}


resource "mso_schema_template_bd" "bds" {
  for_each = var.bds
  schema_id = mso_schema.schema.id
#  template_name = mso_schema.schema.template_name
  template_name = mso_schema.schema.template_name
  name = each.value.name
  display_name = each.value.display_name
#  vrf_name = each.value.vrf_name
  vrf_name = mso_schema_template_vrf.vrfs[each.value.vrf_name].name
  layer2_unknown_unicast = "proxy"
  layer2_stretch = true
#  depends_on = [
#    mso_schema_template_vrf.vrfs,
#  ]
}

resource "mso_schema_template_bd_subnet" "bd_subnets" {
  for_each = {
    for subnet in local.bd_subnets: "${subnet.bd_name}.${subnet.bd_subnet}" => subnet
  }
  schema_id = mso_schema.schema.id
#  template_name = mso_schema.schema.template_name
  template_name = mso_schema.schema.template_name
#  bd_name = each.value.bd_name
  bd_name = mso_schema_template_bd.bds[each.value.bd_name].name
  ip = each.value.bd_subnet
  scope = "public"
  shared = true
#  depends_on = [
#    mso_schema_template_bd.bds
#  ]
}

resource "mso_schema_template_anp" "anps" {
  for_each = var.anps
  schema_id = mso_schema.schema.id
  template = mso_schema.schema.template_name
  name = each.value.name
  display_name = each.value.display_name
#  depends_on = [
#    mso_schema.schema
#  ]
}

resource "mso_schema_template_anp_epg" "epgs" {
  for_each = var.epgs
  schema_id = mso_schema.schema.id
  template_name = mso_schema.schema.template_name
  name = each.value.name
  display_name = each.value.display_name
  anp_name = mso_schema_template_anp.anps[each.value.anp_name].name
  bd_name = mso_schema_template_bd.bds[each.value.bd_name].name
  vrf_name = mso_schema_template_vrf.vrfs[each.value.vrf_name].name
#  depends_on = [
#    mso_schema.schema,
#    mso_schema_template_anp.anps,
#    mso_schema_template_bd.bds,
#    mso_schema_template_vrf.vrfs,
#  ] 
}

resource "mso_schema_site_anp_epg_domain" "epgs_domain" {
  for_each = var.epgs
  schema_id = mso_schema.schema.id
  site_id = mso_schema_site.schema_site1.id
  template_name = mso_schema.schema.template_name
  anp_name = mso_schema_template_anp.anps[each.value.anp_name].name
  epg_name = mso_schema_template_anp_epg.epgs[each.value.name].name
  dn = each.value.dn
  deploy_immediacy = try (each.value.deploy_immediacy, "immediate")
  domain_type = try (each.value.domain_type, "vmmDomain")
  resolution_immediacy = try (each.value.resolution_immediacy, "immediate")
  depends_on = [
#    mso_schema.schema,
#    mso_schema_site.schema_site1,
#    mso_schema_template_anp.anps,
#    mso_schema_template_bd.bds,
#    mso_schema_template_vrf.vrfs,
#    mso_schema_template_anp_epg.epgs,
    aci_vmm_domain.vmm_domain,
  ] 
}

resource "mso_schema_template_filter_entry" "filter_entry" {
  for_each = var.filters
  schema_id = mso_schema.schema.id
  template_name = mso_schema.schema.template_name
  name = each.value.name
  display_name = try (each.value.display_name, each.value.name)
  entry_name = try (each.value.entry_name, each.value.name)
  entry_display_name = try (each.value.entry_display_name, each.value.name)
  ether_type = try (each.value.ether_type, "unspecified")
  ip_protocol = try (each.value.ip_protocol, "unspecified")
  destination_from = try (each.value.destination_from, "unspecified")
  destination_to = try (each.value.destination_to, "unspecified")
  stateful = each.value.stateful
}

locals {
 contract_filter = flatten ([
    for contract_name, contract in var.contracts : [
      for filter_name in contract.filter_list : {
        contract_name = contract_name
        filter_name = filter_name
      }
    ]
  ])
}

resource "mso_schema_template_contract_filter" "con_filter" {
  for_each = {
    for filter_name in local.contract_filter: "${filter_name.contract_name}.${filter_name.filter_name}" => filter_name
  }
  schema_id = mso_schema.schema.id
  template_name = mso_schema.schema.template_name
  contract_name = each.value.contract_name
  filter_type = "bothWay"
  filter_name = each.value.filter_name
  directives = [ "none" ]
  depends_on = [
    mso_schema_template_filter_entry.filter_entry,
    mso_schema_template_contract.template_contract,
  ]
}

resource "mso_schema_template_contract" "template_contract" {
  for_each = var.contracts
  schema_id = mso_schema.schema.id
  template_name = mso_schema.schema.template_name
  contract_name = each.value.contract_name
  display_name = each.value.display_name
  filter_type = each.value.filter_type
  scope = each.value.scope
  filter_relationships = each.value.filter_relationships
  directives = each.value.directives
  depends_on = [
#    mso_schema.schema,
    mso_schema_template_filter_entry.filter_entry
  ]
}

resource "mso_schema_template_anp_epg_contract" "anp_epg_contract_provider" {
  for_each = var.contracts
  schema_id = mso_schema.schema.id
  template_name = mso_schema.schema.template_name
  anp_name = each.value.anp_epg_provider.anp_name
  epg_name = each.value.anp_epg_provider.epg_name
  contract_name = mso_schema_template_contract.template_contract[each.value.contract_name].contract_name
  relationship_type = "provider"
  depends_on = [
#    mso_schema.schema,
#    mso_schema_template_contract.template_contract,
    mso_schema_template_anp_epg.epgs,
    mso_schema_template_anp.anps
  ]
}

resource "mso_schema_template_anp_epg_contract" "anp_epg_contract_consumer" {
  for_each = var.contracts
  schema_id = mso_schema.schema.id
  template_name = mso_schema.schema.template_name
  anp_name = each.value.anp_epg_consumer.anp_name
  epg_name = each.value.anp_epg_consumer.epg_name
  contract_name = mso_schema_template_contract.template_contract[each.value.contract_name].contract_name
  relationship_type = "consumer"
  depends_on = [
#    mso_schema_template_contract.template_contract,
    mso_schema_template_anp_epg.epgs,
    mso_schema_template_anp.anps,
  ]
}

/*
data "mso_schema_template" "template" {
  name = mso_schema.schema.template_name
  schema_id = mso_schema.schema.id
  depends_on = [
    mso_schema.schema,
  ]
}
*/

resource "mso_schema_template_deploy" "this" {
  schema_id = mso_schema.schema.id
  template_name = mso_schema.schema.template_name
  site_id = mso_schema_site.schema_site1.site_id
  depends_on = [
#    mso_schema_template_service_graph.sg,
    mso_schema_template_anp_epg.epgs,
    mso_schema_template_anp_epg_contract.anp_epg_contract_provider,
    mso_schema_template_anp_epg_contract.anp_epg_contract_consumer,
    mso_schema_template_vrf.vrfs,
#    mso_schema_template_l3out.l3out,
    mso_schema_template_bd_subnet.bd_subnets,
#    mso_schema_template_external_epg.ext_epg,
    mso_schema_template_filter_entry.filter_entry,
    mso_schema_template_contract_filter.con_filter,
  ]
}

data "aci_tenant" "this" {
  name = var.tenant.name
  depends_on = [
    mso_tenant.tn,
  ]
}

# Create L4-L7 Device.
resource "aci_rest" "device" {
    for_each = var.sg
    path    = "api/node/mo/${data.aci_tenant.this.id}/lDevVip-${each.value.name}.json"
    payload = <<EOF
{
		"vnsLDevVip": {
			"attributes": {
				"activeActive": "no",
				"annotation": "",
				"contextAware": "single-Context",
				"devtype": "${each.value.devtype}",
				"dn": "${data.aci_tenant.this.id}/lDevVip-${each.value.name}",
				"funcType": "GoTo",
				"isCopy": "no",
				"managed": "no",
				"mode": "legacy-Mode",
				"name": ${each.value.name},
				"nameAlias": "",
				"packageModel": "",
				"promMode": "no",
				"svcType": "FW",
				"trunking": "no",
				"userdom": ":all:"
			},
			"children": [{
				"vnsRsALDevToPhysDomP": {
					"attributes": {
						"annotation": "",
						"tDn": "uni/phys-${each.value.phydomain_name}",
						"userdom": ":all:"
					}
				}
			}, {
				"vnsLIf": {
					"attributes": {
						"annotation": "",
						"encap": "${each.value.vlan}",
						"lagPolicyName": "",
						"name": "cl-${each.value.name}",
						"nameAlias": "",
						"userdom": ":all:"
					},
					"children": [{
						"vnsRsCIfAttN": {
							"attributes": {
								"annotation": "",
								"tDn": "${data.aci_tenant.this.id}/lDevVip-${each.value.name}/cDev-${each.value.name}-intf-${each.value.leaf_block}-${each.value.card}-${each.value.port}/cIf-[${each.value.leaf_block}-${each.value.card}-${each.value.port}]",
								"userdom": ":all:"
							}
						}
					}]
				}
			}, {
				"vnsCDev": {
					"attributes": {
						"annotation": "",
						"cloneCount": "0",
						"devCtxLbl": "",
						"host": "",
						"isCloneOperation": "no",
						"isTemplate": "no",
						"name": "${each.value.name}-intf-${each.value.leaf_block}-${each.value.card}-${each.value.port}",
						"nameAlias": "",
						"userdom": ":all:",
						"vcenterName": "",
						"vmName": ""
					},
					"children": [{
						"vnsCIf": {
							"attributes": {
								"annotation": "",
								"encap": "unknown",
								"name": "${each.value.leaf_block}-${each.value.card}-${each.value.port}",
								"nameAlias": "",
								"userdom": ":all:",
								"vnicName": ""
							},
							"children": [{
								"vnsRsCIfPathAtt": {
									"attributes": {
										"annotation": "",
										"tDn": "topology/pod-1/paths-${each.value.leaf_block}/pathep-[eth${each.value.card}/${each.value.port}]",
										"userdom": ":all:"
									}
								}
							}]
						}
					}]
				}
			}]
		}
	}
EOF
}

# Create L4-L7 Service Graph template.
resource "aci_l4_l7_service_graph_template" "this" {
    for_each = var.sg
    tenant_dn                         = data.aci_tenant.this.id
    name                              = format ("%s%s", "sg-",each.value.name)
    description                       = each.value.description
    l4_l7_service_graph_template_type = "legacy"
    ui_template_type                  = "UNSPECIFIED"
}

# Create L4-L7 Service Graph template node.
resource "aci_function_node" "this" {
    for_each = var.sg
    l4_l7_service_graph_template_dn = aci_l4_l7_service_graph_template.this[each.value.name].id
    name                            = each.value.site_nodes[0].node_name
    func_template_type              = "FW_ROUTED"
    func_type                       = "GoTo"
    is_copy                         = "no"
    managed                         = "no"
    routing_mode                    = "Redirect"
    sequence_number                 = "0"
    share_encap                     = "no"
    relation_vns_rs_node_to_l_dev   = "${data.aci_tenant.this.id}/lDevVip-${each.value.name}"
}

# Create L4-L7 Service Graph template T1 connection.
resource "aci_connection" "t1-n1" {
    for_each = var.sg
    l4_l7_service_graph_template_dn = aci_l4_l7_service_graph_template.this[each.value.name].id
    name           = "C2"
    adj_type       = "L3"
    conn_dir       = "provider"
    conn_type      = "external"
    direct_connect = "no"
    unicast_route  = "yes"
    relation_vns_rs_abs_connection_conns = [
        aci_l4_l7_service_graph_template.this[each.value.name].term_prov_dn,
        aci_function_node.this[each.value.name].conn_provider_dn
    ]
}

# Create L4-L7 Service Graph template T2 connection.
resource "aci_connection" "n1-t2" {
    for_each = var.sg
    l4_l7_service_graph_template_dn = aci_l4_l7_service_graph_template.this[each.value.name].id
    name                            = "C1"
    adj_type                        = "L3"
    conn_dir                        = "provider"
    conn_type                       = "external"
    direct_connect                  = "no"
    unicast_route                   = "yes"
    relation_vns_rs_abs_connection_conns = [
        aci_l4_l7_service_graph_template.this[each.value.name].term_cons_dn,
        aci_function_node.this[each.value.name].conn_consumer_dn
    ]
}

# Create L4-L7 Logical Device Context / Devices Selection Policies.
resource "aci_logical_device_context" "this" {
    for_each = var.sg
    tenant_dn                          = data.aci_tenant.this.id
    ctrct_name_or_lbl                  = each.value.contract_name
    graph_name_or_lbl                  = format ("%s%s", "sg-",each.value.name)
    node_name_or_lbl                   = aci_function_node.this[each.value.name].name
#    relation_vns_rs_l_dev_ctx_to_l_dev = "${data.aci_tenant.this.id}/lDevVip-${each.value.name}"
    relation_vns_rs_l_dev_ctx_to_l_dev = aci_rest.device[each.value.name].id

}

data "aci_bridge_domain" "bds" {
  for_each = var.sg
  tenant_dn = data.aci_tenant.this.id
  name = each.value.bd_name
  depends_on = [
    mso_schema_template_deploy.this
  ]
}

# Create L4-L7 Logical Device Interface Contexts.
resource "aci_logical_interface_context" "consumer" {
  for_each = var.sg
	logical_device_context_dn        = aci_logical_device_context.this[each.value.name].id
	conn_name_or_lbl                 = "consumer"
	l3_dest                          = "yes"
	permit_log                       = "no"
  relation_vns_rs_l_if_ctx_to_l_if = "${data.aci_tenant.this.id}/lDevVip-${each.value.name}/lIf-cl-${each.value.name}"
  relation_vns_rs_l_if_ctx_to_bd   = data.aci_bridge_domain.bds[each.value.name].id
  relation_vns_rs_l_if_ctx_to_svc_redirect_pol = aci_service_redirect_policy.pbr[each.value.pbr_name].id
  depends_on = [
    aci_rest.device,
  ]
}

resource "aci_logical_interface_context" "provider" {
  for_each = var.sg
	logical_device_context_dn        = aci_logical_device_context.this[each.value.name].id
	conn_name_or_lbl                 = "provider"
	l3_dest                          = "yes"
	permit_log                       = "no"
  relation_vns_rs_l_if_ctx_to_l_if = "${data.aci_tenant.this.id}/lDevVip-${each.value.name}/lIf-cl-${each.value.name}"
  relation_vns_rs_l_if_ctx_to_bd   = data.aci_bridge_domain.bds[each.value.name].id
  relation_vns_rs_l_if_ctx_to_svc_redirect_pol = aci_service_redirect_policy.pbr[each.value.pbr_name].id
  depends_on = [
    aci_rest.device,
  ]
}

data "aci_l4_l7_service_graph_template" "sg_template" {
  for_each = var.sg
  tenant_dn = data.aci_tenant.this.id
  name = format ("%s%s", "sg-", each.value.name)
  depends_on = [
    mso_schema_template_deploy.this
  ]
}

resource "aci_contract_subject" "subj" {
  for_each = var.sg
  contract_dn = "${data.aci_tenant.this.id}/brc-${each.value.contract_name}"
  name = "msc-subject"
  relation_vz_rs_subj_graph_att = data.aci_l4_l7_service_graph_template.sg_template[each.value.name].id
}

# Create IP SLA Monitoring Policy
resource "aci_rest" "ipsla" {
    for_each = var.pbr
    path    = "api/node/mo/${data.aci_tenant.this.id}/ipslaMonitoringPol-${each.value.ipsla_name}.json"
    payload = <<EOF
{
	"fvIPSLAMonitoringPol": {
		"attributes": {
			"dn": "${data.aci_tenant.this.id}/ipslaMonitoringPol-${each.value.ipsla_name}",
			"name": "${each.value.ipsla_name}",
			"rn": "ipslaMonitoringPol-${each.value.ipsla_name}",
			"status": "created"
		},
		"children": []
	}
}
EOF  
}

# Create Redirect Health Group
resource "aci_rest" "rh" {
    for_each = var.pbr
    path    = "api/node/mo/${data.aci_tenant.this.id}/svcCont/redirectHealthGroup-${each.value.rh_grp_name}.json"
    payload = <<EOF
{
	"vnsRedirectHealthGroup": {
		"attributes": {
			"dn": "${data.aci_tenant.this.id}/svcCont/redirectHealthGroup-${each.value.rh_grp_name}",
			"name": "${each.value.rh_grp_name}",
			"rn": "redirectHealthGroup-${each.value.rh_grp_name}",
			"status": "created"
		},
		"children": []
	}
}
EOF
}

resource "aci_service_redirect_policy" "pbr" {
  for_each = var.pbr
  tenant_dn = data.aci_tenant.this.id
  name = each.value.name
  dest_type = "L3"
#  relation_vns_rs_ipsla_monitoring_pol = "${data.aci_tenant.this.id}/ipslaMonitoringPol-${each.value.ipsla_name}"
  relation_vns_rs_ipsla_monitoring_pol = aci_rest.ipsla[each.value.name].id
}

resource "aci_destination_of_redirected_traffic" "pbr" {
  for_each = var.pbr
  service_redirect_policy_dn = aci_service_redirect_policy.pbr[each.value.name].id
  ip = each.value.ip
  mac = each.value.mac
#  relation_vns_rs_redirect_health_group = "${data.aci_tenant.this.id}/svcCont/redirectHealthGroup-${each.value.rh_grp_name}"
  relation_vns_rs_redirect_health_group = aci_rest.rh[each.value.name].id
}

