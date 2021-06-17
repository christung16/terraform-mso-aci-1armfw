## Terraform Integrate ACI and MSO Configuration

By leveraging the advantage of Terraform IaC characteristic (https://developer.cisco.com/iac/), it can be easily and consistently build and rebuild the ACI/MSO VMM integration and other features PoC. It also integrates both controllers config into a single configuration file (.tfvars). It is much more human readable and easily to make the changes.

The repository is referring to (https://github.com/christung16/terraform-mso-aci) example 3 - One arm firewall setup

Another purpose of this repository is to learn a very consistent way to build your own main.tf. How to handle json type configuration in terraform for network resources. Learn how to manupilate different data structure type which usually used in network environment.

## Use Case Description

3. one-arm-firewall

![image](https://user-images.githubusercontent.com/21293832/122451862-33df6d00-cfdb-11eb-9102-cf240414a5c1.png)


## Installation

To build the lab:
1. Copy terraform.tfvars.usercase1 to terraform.tfvars. Or you can modify it directly for your own case
2. Modify username/password and IP address for APIC / MSO / VCenter
3. terraform init
4. terraform plan
5. terraform apply --auto-approve --parallelism=1
6. Open MSO, click Schema, click template, click "Deploy to Sites" in order to deploy the overlay config to APIC and associate the underlay

To destroy the lab:

7. Open MSO, click Schema, there are "..." under the site, click "Undeploy template" in order to deprovision the overlay config from APIC
8. "terraform destroy --auto-approve --parallelism=1" to destroy the both config from APIC and MSO

## Configuration

- Copy terraform.tfvars.usercase1 or terraform.tfvars.usercase2 to terraform.tfvars. 
- Build you own Use case by modifying terraform.tfvars

## Usage

1. Modify username/password and URL

        mso_user = {
            username = "admin"
            password = "<password>"  // for office lab
            url = "https://<mso ip>"

        }

        aci_user = {
            username = "admin"
            password = "<password>"
            url = "https://<apic ip>"
        }

        vcenter_user = {
            username = "administrator@vsphere.local"
            password = "<password>"
            url = "<vcenter ip>"   
        }

2. Be minded that in vmm_vmware section, need to enter the vcenter info:

            vmm_vmware = {
                gen_com_vswitch = {
                    provider_profile_dn = "uni/vmmp-VMware"
                    name = "gen_com_vswitch"
                    vlan_pool = "gen_com_vlan_pool_1"
                    vcenter_host_or_ip = "<vcenter ip>"
                    vcenter_datacenter_name = "ACI-Datacenter"
                    dvs_version = "6.6"
                    vcenter_usr = "administrator@vsphere.local"
                    vcenter_pwd = "<password>"
                    aaep_name = "aaep_gen_com_vswitch" 
                }
            }

### Learn how to manipulate the data structures which commonly used in network environment

1. Map in the Map
   In .tfvars
   
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

  Single Resource with for_each
  In main.tf

        resource "aci_cdp_interface_policy" "cdp" {
          for_each = var.cdp
          name = each.value.name
          admin_st = each.value.admin_st
        }

2. List in the Map
   In .tfvars

        bds = {
            GENERAL_BD1 = {
                name = "GENERAL_BD1"
                display_name = "GENERAL_BD1"
                vrf_name = "GENERAL_VRF"
                subnets = [ "192.168.100.254/24", "10.207.40.251/24", "10.207.40.252/24" ]
            }
        }

  Flatten it and use for_each
  In main.tf

          bd_subnets = flatten ([
            for bd_key, bd in var.bds : [
              for subnet in bd.subnets : {
                bd_name = bd_key
                bd_subnet = subnet

              }
            ]
          ])

        resource "mso_schema_template_bd_subnet" "bd_subnets" {
          for_each = {
            for subnet in local.bd_subnets: "${subnet.bd_name}.${subnet.bd_subnet}" => subnet
          }
          schema_id = mso_schema.schema.id
          template_name = var.template_name
          bd_name = each.value.bd_name
          ip = each.value.bd_subnet
          scope = "public"
          shared = true
          depends_on = [
            mso_schema_template_bd.bds
          ]
        }

## How to test

1. You need to have ACI, MSO and UCS with VMware/Vcenter installed

## How to destroy the resources

1. Open MSO, click Schema, there are "..." under the site, choose Undeploy Template. Otherwise you can't destroy the resouces correctly
2. terraform destroy --auto-approve --parallelism=1
    
## Known issues:

1. terraform apply need to use "parallelism=1" due to MSO limitation
2. After successfully applied, you need to manually map the upnlink into the vmnic 
3. When destroy the resource, remember to "Undeploy template" first
4. There are still missing a lot of advance features like lacp, vpc, pbr, service graph, etc. You can try to build your own and share it out.
    
## Getting help

Instruct users how to get help with this code; this might include links to an issues list, wiki, mailing list, etc.

----

## Credits and references

1. [Cisco Infrastructure As Code](https://developer.cisco.com/iac/)
2. [ACI provider Terraform](https://registry.terraform.io/providers/CiscoDevNet/aci/latest/docs)
3. [MSO provider Terraform](https://registry.terraform.io/providers/CiscoDevNet/mso/latest/docs)
4. [Automation Terraform](https://developer.cisco.com/automation-terraform/)
