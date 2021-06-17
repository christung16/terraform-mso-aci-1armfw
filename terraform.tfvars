# AUTHOR(s): Chris Tung <yitung@cisco.com>

mso_user = {
    username = "admin"
    password = "<password>"  // your MSO password
    url = "https://<MSO IP>"

}

aci_user = {
    username = "admin"
    password = "<password>"  // your ACI password
    url = "https://<APIC IP>"
}

vcenter_user = {
    username = "administrator@vsphere.local"
    password = "<password>"   // your vCenter password
    url = "<VCenter IP>"        // Remark: no need https:// in the beginning
}
// Caveat: No "." in the name // Underlay config in APIC

cdp = {
    cdp-enable = {
        name = "gen_com_cdp_enable"
        admin_st = "enabled"
    }
    cdp-disable = {
        name = "gen_com_cdp_disable"
        admin_st = "disabled"
    }
}

lldp = {
    lldp-enable = {
        name = "gen_com_lldp_enable"
        description = "gen_com_lldp_enable"
        admin_tx_st = "enabled"
        admin_rx_st = "enabled"
    }
    lldp-disable = {
        name = "gen_com_lldp_disable"
        description = "gen_com_lldp_disable"
        admin_tx_st = "disabled"
        admin_rx_st = "disabled"
    }
}

vlan_pool = {
    gen_com_vlan_pool_1 = {
        name = "gen_com_vlan_pool_1"
        alloc_mode = "dynamic"
        from = "vlan-2001"
        to = "vlan-3000"
    }
    gen_com_vlan_pool_2 = {
        name = "gen_com_vlan_pool_2"
        alloc_mode = "dynamic"
        from = "vlan-3001"
        to = "vlan-3900"
    }
    asa_phy_vlan_pool = {
        name = "asa_phy_vlan_pool"
        alloc_mode = "static"
        from = "vlan-2501"
        to = "vlan-2501"
    }
}

vmm_vmware = {
    gen_com_vswitch = {
        provider_profile_dn = "uni/vmmp-VMware"
        name = "gen_com_vswitch"
        vlan_pool = "gen_com_vlan_pool_1"
        vcenter_host_or_ip = "<VCenter ip>"
        vcenter_datacenter_name = "ACI-Datacenter"
        dvs_version = "6.6"
        vcenter_usr = "administrator@vsphere.local"
        vcenter_pwd = "<password>"
        aaep_name = "aaep_gen_com_vswitch" 
        esxi_hosts = [ "10.74.202.122" ]

    }
}

phydomain = {
    asa_fw_phydomain = {
        name = "asa_fw_phydomain"
        vlan_pool = "asa_phy_vlan_pool"
        aaep_name = "aaep_asa_phydomain"
    }

}

l3domain = {
}

access_port_group_policy = {
    leaf_access_port_101_1_12_vmm_vcenter = {
        name = "leaf_access_port_101_1_12_vmm_vcenter"
        lldp_status = "gen_com_lldp_disable"
        cdp_status = "gen_com_cdp_enable"
        aaep_name = "aaep_gen_com_vswitch"
        leaf_profile = "leaf-101-Chris-profile"
        leaf_block = 101
        from_card = 1
        from_port = 12
        to_card = 1
        to_port = 12
    }
    leaf_access_port_101_1_20_phydomain = {
        name = "leaf_access_port_101_1_20_phydomain"
        lldp_status = "gen_com_lldp_disable"
        cdp_status = "gen_com_cdp_enable"
        aaep_name = "aaep_asa_phydomain"
        leaf_profile = "leaf-101-Chris-profile"
        leaf_block = 101
        from_card = 1
        from_port = 20
        to_card = 1
        to_port = 20
    }
}

sg = {
    one-arm-fw = {
        name = "one-arm-fw"
        service_node_type = "firewall"
        description = "one-arm-fw"
        devtype = "PHYSICAL"    // capital letters
        phydomain_name = "asa_fw_phydomain"
        vlan = "vlan-2501"
        leaf_block = 101
        card = 1
        port = 20
        site_nodes = [{
            site_name = "aci_site1"
            tenant_name = "General_Company_Tenant"
            node_name = "one-arm-fw"
            }
        ]
        contract_name = "Con_WEB_EPG_to_DATABASE_EPG"
        bd_name = "GENERAL_BD1"
        pbr_name = "pbr-one-arm-fw"

    }
}

pbr = {
    pbr-one-arm-fw = {
        ipsla_name = "ipsla_icmp"
        rh_grp_name = "rh_grp"
        name = "pbr-one-arm-fw"
        ip = "192.168.100.253"
        mac = "00:50:56:9a:b4:68"
    }
}

// Overlay config in MSO

template_name = "General_Company_Template"
schema_name = "General_Company_Schema"
mso_site = "aci-site1"


tenant = {
    name = "General_Company_Tenant"
    description = "Tenant Created by Terraform"
}

anps = {
    GENERAL_AP = {
        name = "GENERAL_AP"
        display_name = "GENERAL_AP"
    }
}

vrfs = {
    GENERAL_VRF = {
        name = "GENERAL_VRF"
        display_name = "GENERAL_VRF"
    }
}

bds = {
    GENERAL_BD1 = {
        name = "GENERAL_BD1"
        display_name = "GENERAL_BD1"
        vrf_name = "GENERAL_VRF"
        subnets = [ "192.168.100.254/24", "10.207.40.251/24", "10.207.40.252/24" ]
    }
    GENERAL_BD2 = {
        name = "GENERAL_BD2"
        display_name = "GENERAL_BD2"
        vrf_name = "GENERAL_VRF"
        subnets = [ "192.168.200.254/24" ]
    }
}

epgs = {
    WEB_EPG = {
        name = "WEB_EPG"
        display_name = "WEB_EPG"
        anp_name = "GENERAL_AP" 
        bd_name = "GENERAL_BD1"
        vrf_name = "GENERAL_VRF"
        dn = "gen_com_vswitch"
    }
    DATABASE_EPG = {
        name = "DATABASE_EPG"
        display_name = "DATABASE_EPG"
        anp_name = "GENERAL_AP" 
        bd_name = "GENERAL_BD1"
        vrf_name = "GENERAL_VRF"
        dn = "gen_com_vswitch"
    }
}

filters = {
    filter_all = {
        name = "filter_all"
        display_name = "filter_all_display_name"
        entry_name = "filter_all_entry_name"
        entry_display_name = "filter_all_entry_display_name"
        ether_type = "unspecified"
        ip_protocol = "unspecified"
        destination_from = "unspecified"
        destination_to = "unspecified"
        stateful = false
    }
    tcp_40000 = {
        name = "tcp_40000"
        ether_type = "ip"
        ip_protocol = "tcp"
        destination_from = "40000"
        destination_to = "40000"
        stateful=true
    }
    icmp = {
        name = "icmp"
        ether_type = "ip"
        ip_protocol = "icmp"
        stateful=false
    }
    tcp_22 = {
        name = "tcp_22"
        ether_type = "ip"
        ip_protocol = "tcp"
        destination_from = "ssh"
        destination_to = "ssh"
        stateful=true
    }
    tcp_3306 = {
        name = "tcp_3306"
        ether_type = "ip"
        ip_protocol = "tcp"
        destination_from = "3306"
        destination_to = "3306"
        stateful=true
    }
}

contracts = {
    Con_WEB_EPG_to_DATABASE_EPG = {
        contract_name = "Con_WEB_EPG_to_DATABASE_EPG"
        display_name = "Con_WEB_EPG_to_DATABASE_EPG"
        filter_type = "bothWay"
        scope = "tenant"
        filter_relationships = {
            filter_name = "tcp_40000"
        }
        filter_list = [ "icmp", "tcp_22" ]
        directives = [ "none" ]
        anp_epg_consumer = {
            anp_name = "GENERAL_AP"
            epg_name = "WEB_EPG"
        }
        anp_epg_provider = {
            anp_name = "GENERAL_AP"
            epg_name = "DATABASE_EPG"
        }
    }
}

l3outs = {
}

ext_epg = {
}