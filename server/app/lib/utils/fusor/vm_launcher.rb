require 'fog'

module Utils
  module Fusor
    class VMLauncher
      def initialize(deployment, appliance="cfme", provider="RHEV")
        @deployment = deployment
        @compute_resource = ComputeResource.find_by_name("#{deployment.label}-#{provider}")
        @appliance = appliance
        @provider = provider
        @profile_name = "#{deployment.label}-#{appliance}"
        @compute_profile = ComputeProfile.create("name" => @profile_name)
        @compute_attrs = {"compute_profile_id" => @compute_profile.id,
                          "compute_resource_id" => @compute_resource.id}.with_indifferent_access
        @host_name = "#{deployment.label.tr('_', '-')}-#{appliance}"

        @host_attrs = init_host_attrs

        if appliance == "cfme" && provider == "RHEV" 
          init_cfme_on_rhev_compute_attrs
        elsif appliance == "cfme" && provider == "RHOS"
          init_cfme_on_rhev_compute_attrs
        elsif appliance == "ose" && provider == "RHEV"
          init_ose_on_rhev_compute_attrs
        else
          fail _("VMLauncher (initialize): unsupported appliance/provider:  #{appliance}/#{provider}!")
        end
      end

      def init_host_attrs
        host_attrs = {"name" => @host_name,
                      "location_id" => Location.find_by_name('Default Location').id,
                      "environment_id" => Environment.where(:katello_id => "Default_Organization/Library/Fusor_Puppet_Content").first.id,
                      "organization_id" => @deployment["organization_id"],
                      "compute_resource_id" => @compute_resource.id,
                      "enabled" => "1",
                      "managed" => "1",
                      "architecture_id" => Architecture.find_by_name('x86_64')['id'],
                      "operatingsystem_id" => Operatingsystem.find_by_title('RedHat 7.1')['id']}.with_indifferent_access
      end

      def update_host_attrs(attrs)
        # will update the host_attrs, or add to it, if it's new
        attrs.each do |k, v|
          @host_attrs[k] = v
        end
      end

      def init_cfme_on_rhev_compute_attrs
        cl_id  = @compute_resource.clusters.find { |c| c.name == @deployment.rhev_cluster_name }.id
        net_id = @compute_resource.available_networks(cl_id).first.id
        storage_id  = @compute_resource.available_storage_domains(cl_id).first.id
        template_id = @compute_resource.templates.find { |t| t.name == "#{@deployment.label}-#{@appliance}-template" }.id
        volumes_attributes = {"new_volumes" => {
                                 "size_gb" => "",
                                 "storage_domain" => storage_id,
                                 "_delete" => "",
                                 "id" => "",
                                 "preallocate" => "0"
                               }.with_indifferent_access,
                               "0" => {
                                 "size_gb" => 40,
                                 "storage_domain" => storage_id,
                                 "_delete" => "",
                                 "id" => "",
                                 "preallocate" => "0"
                               }.with_indifferent_access
                             }.with_indifferent_access

        interfaces_attributes = {"new_interfaces" => {
                                     "name" => "",
                                     "network" => net_id,
                                     "delete" => ""
                                   }.with_indifferent_access,
                                   "0" => {
                                     "name" => "eth0",
                                     "network" => net_id,
                                     "delete" => ""
                                   }.with_indifferent_access
                                 }.with_indifferent_access
        vm_attrs = { "cluster"  => cl_id,
                     "template" => template_id,
                     "cores"    => 4,
                     "memory"   => 6_442_450_944}.with_indifferent_access
        vm_attrs["interfaces_attributes"] = interfaces_attributes
        vm_attrs["volumes_attributes"] = volumes_attributes
        @compute_attrs["vm_attrs"] = vm_attrs
      end

      def init_ose_on_rhev_compute_attrs
        #use same as rhev compute attrs for now
        init_cfme_on_rhev_compute_attrs
      end

      def init_cfme_on_osp_compute_attrs
        image = Image.create( "name" => @profile_name,
                              "username" => 'root',
                              "user_data" => 1,
                              "uuid" => @compute_resource.available_images.find { |hash| @profile_name == hash.name }.id,
                              "compute_resource_id" => @compute_resource.id,
                              "operatingsystem_id" => Operatingsystem.find_by_title('RedHat 7.1')['id'],
                              "architecture_id" => Architecture.find_by_name('x86_64')['id'])         
        overcloud = {:openstack_auth_url => "http://#{@deployment.openstack_overcloud_address}:5000/v2.0/tokens",
                     :openstack_username => 'admin', :openstack_tenant => 'admin',
                     :openstack_api_key  => @deployment.openstack_overcloud_password }
        keystone  = Fog::Identity::OpenStack.new(overcloud)
        tenant    = keystone.get_tenants_by_name(@deployment.label).body["tenant"]
        neutron   = Fog::Network::OpenStack.new(overcloud)
        nic       = neutron.list_networks.body["networks"].find { |hash| "#{@deployment.label}-net" == hash["name"] }['id']

        vm_attrs  = {"flavor_ref" => "4",
                     "network" => "#{@deployment.label}-float-net",
                     "image_ref" => image.find_by_name(@profile_name).uuid,
                     "security_groups" => "#{deployment.label}-sec-group",
                     "nics" => ["", nic],
                     "tenant_id" => tenant['id']
                   }.with_indifferent_access

        @compute_attrs["vm_attrs"] = vm_attrs
      end

      def update_compute_attrs(attrs)
        # will update the compute_attrs, or add to it, if it's new
        attrs.each do |k, v|
          @compute_attrs[k] = v
        end
      end

      def launch_vm_completed
        ::Fusor.log.info "VMLauncher: #{@appliance} Launch on #{@provider} Completed"
      end

      def launch_vm_failed
        fail _("VMLauncher: #{@appliance} Launch on #{@provider} FAILED")
      end

      def create_compute_profile
        ComputeAttribute.create(@compute_attrs)
      end

      def launch_vm
        host = ::Host.create(@host_attrs)
        if host.errors.empty?
          launch_vm_completed
          return host
        else
          launch_vm_failed
        end
      end
    end
  end
end
