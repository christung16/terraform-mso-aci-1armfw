# AUTHOR(s): Chris Tung <yitung@cisco.com>

terraform {
  required_providers {
    aci = {
        source = "CiscoDevNet/aci"
        version = "0.7.0"
    }
  }
}

variable "name" {
  type = string
}

variable "lldp_status" {
  type = string
}

variable "cdp_status" {
  type = string
}

variable "aaep_name" {
  type = string
}

variable "leaf_profile" {
  type = string
}

variable "leaf_block" {
  type = string
}

variable "from_card" {
  type = string
}

variable "from_port" {
  type = string
}

variable "to_card" {
  type = string
}

variable "to_port" {
  type = string
}



/*
data "aci_vmm_domain" "vds" {
  provider_profile_dn = "uni/vmmp-VMware"
  name = var.vmm_vcenter.vds_name
}

resource "aci_attachable_access_entity_profile" "vmm_vcenter" {
  name = var.vmm_vcenter.aaep_name
  relation_infra_rs_dom_p = [data.aci_vmm_domain.vds.id]
}
*/

data "aci_lldp_interface_policy" "lldp_status" {
  name = var.lldp_status
}

data "aci_cdp_interface_policy" "cdp_status" {
  name = var.cdp_status
}

data "aci_attachable_access_entity_profile" "aaep" {
  name = var.aaep_name
}

resource "aci_leaf_access_port_policy_group" "leaf_access_port_pg" {
  name = var.name
  relation_infra_rs_lldp_if_pol = data.aci_lldp_interface_policy.lldp_status.id
  relation_infra_rs_cdp_if_pol = data.aci_cdp_interface_policy.cdp_status.id
  relation_infra_rs_att_ent_p = data.aci_attachable_access_entity_profile.aaep.id
}

resource "aci_leaf_interface_profile" "leaf_interface_profile" {
  name = format("%s%s",var.name,"_intf_p")
}

resource "aci_access_port_selector" "access_port_selector" {
  leaf_interface_profile_dn = aci_leaf_interface_profile.leaf_interface_profile.id
  name = format("%s%s",var.name,"_port_selector")
  access_port_selector_type = "range"
  relation_infra_rs_acc_base_grp = aci_leaf_access_port_policy_group.leaf_access_port_pg.id
}

resource "aci_access_port_block" "access_port_block" {
  access_port_selector_dn = aci_access_port_selector.access_port_selector.id
  name = format("%s%s",var.name,"_port_block")
  from_card = var.from_card
  from_port = var.from_port
  to_card = var.to_card
  to_port = var.to_port
}

resource "aci_leaf_profile" "leaf_profile" {        
  name = var.leaf_profile
  relation_infra_rs_acc_port_p = [aci_leaf_interface_profile.leaf_interface_profile.id]
}

resource "aci_leaf_selector" "leaf_selector" {
  leaf_profile_dn = aci_leaf_profile.leaf_profile.id
  name = format("%s%s", var.leaf_profile,"_leaf_selector")
  switch_association_type = "range"
}

resource "aci_node_block" "node_block" {
  switch_association_dn = aci_leaf_selector.leaf_selector.id
  name = format("%s%s", var.leaf_profile,"_leaf_nodes")
  from_ = var.leaf_block
  to_ = var.leaf_block
}