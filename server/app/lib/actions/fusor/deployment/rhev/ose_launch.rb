#
# Copyright 2015 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
require 'securerandom'

module Actions
  module Fusor
    module Deployment
      module Rhev
        #Setup and Launch OSE VM
        class OseLaunch < Actions::Fusor::FusorBaseAction
          def humanized_name
            _('Setup and Launch OSE VM')
          end

          def plan(deployment)
            super(deployment)
            plan_self(deployment_id: deployment.id)
          end

          # rubocop:disable MethodLength
          # rubocop:disable AbcSize
          def run
            ::Fusor.log.info '====== OSE Launch run method ======'
            deployment = ::Fusor::Deployment.find(input[:deployment_id])

            generate_root_password(deployment)

            ks_name = "OpenShift Kickstart"
            snippet_name = "rhevm_guest_agent"
            repos = SETTINGS[:fusor][:content][:openshift].map { |p| p[:repository_set_label] if p[:repository_set_label] =~ /rpms$/ }.compact
            ct_util = Utils::Fusor::ConfigTemplateUtils.new({:rhevm_guest_agent_snippet_name => snippet_name, :enabled_repos => repos})
            ret = ct_util.ensure_ks_with_snippet(ks_name, snippet_name)
            fail _("====== Could not ensure '#{ks_name}' with '#{snippet_name}'") unless ret

            ks = ProvisioningTemplate.find_by_name(ks_name)
            ks.hostgroup_ids = hostgroup.id
            ks.save!

            vm_init_params = {:deployment => deployment,
                              :application => 'ose',
                              :provider => deployment.openshift_install_loc,
                              :hostgroup => hostgroup,
                              :os => os.title,
                              :arch => 'x86_64',
                              :ptable_name => ptable_name}

            # launch master nodes
            master_vm_launch_params = {:cpu => deployment.openshift_master_vcpu,
                                       :ram => deployment.openshift_master_ram,
                                       :vda_size => deployment.openshift_master_disk,
                                       :other_disks => [deployment.openshift_storage_size]}
            for i in 1..deployment.openshift_number_master_nodes do
              vmlauncher = Utils::Fusor::VMLauncher.new(vm_init_params)
              fail _("====== vmlauncher is nil for Master #{i}! ======") unless vmlauncher

              vmlauncher.set_hostname("#{deployment.label.tr('_', '-')}-ose-master#{i}")
              host = vmlauncher.launch_openshift_vm(master_vm_launch_params)
              if host.nil?
                fail _("====== Launch OSE Master #{i} VM FAILED! ======")
              else
                deployment.ose_master_hosts << host
                ::Fusor.log.debug "====== OSE Launched VM Name : #{host.name} ======"
                ::Fusor.log.debug "====== OSE Launched VM IP   : #{host.ip}   ======"
              end
            end
            subdomain = Net::DNS::ARecord.new({:ip => host.ip,
                                               :hostname => "*.#{deployment.openshift_subdomain_name}.#{Domain.find(host.domain_id)}",
                                               :proxy => Domain.find(host.domain_id).proxy})
            if subdomain.valid?
              ::Fusor.log.debug "====== OSE wildcard subdomain is not valid, it might conflict with a previous entry. Skipping. ======"
            else
              subdomain.create
              ::Fusor.log.debug "====== OSE wildcard subdomain created successfully ======"
            end

            # launch worker nodes
            worker_vm_launch_params = {:cpu => deployment.openshift_node_vcpu,
                                       :ram => deployment.openshift_node_ram,
                                       :vda_size => deployment.openshift_node_disk,
                                       :other_disks => [deployment.openshift_storage_size]}
            for i in 1..deployment.openshift_number_worker_nodes do
              vmlauncher = Utils::Fusor::VMLauncher.new(vm_init_params)
              fail _("====== vmlauncher is nil for Worker #{i}! ======") unless vmlauncher

              vmlauncher.set_hostname("#{deployment.label.tr('_', '-')}-ose-node#{i}")
              host = vmlauncher.launch_openshift_vm(worker_vm_launch_params)
              if host.nil?
                fail _("====== Launch OSE Worker #{i} VM FAILED! ======")
              else
                deployment.ose_worker_hosts << host
                ::Fusor.log.debug "====== OSE Launched VM Name : #{host.name} ======"
                ::Fusor.log.debug "====== OSE Launched VM IP   : #{host.ip}   ======"
              end
            end

            # launch infra nodes
            for i in 1 + deployment.openshift_number_worker_nodes..deployment.openshift_number_infra_nodes + deployment.openshift_number_worker_nodes do
              vmlauncher = Utils::Fusor::VMLauncher.new(vm_init_params)
              fail _("====== vmlauncher is nil for Infra #{i}! ======") unless vmlauncher

              vmlauncher.set_hostname("#{deployment.label.tr('_', '-')}-ose-node#{i}")
              host = vmlauncher.launch_openshift_vm(worker_vm_launch_params)
              if host.nil?
                fail _("====== Launch OSE Infra #{i} VM FAILED! ======")
              else
                deployment.ose_worker_hosts << host
                ::Fusor.log.debug "====== OSE Launched VM Name : #{host.name} ======"
                ::Fusor.log.debug "====== OSE Launched VM IP   : #{host.ip}   ======"
              end
            end

            # launch ha nodes
            ha_vm_launch_params = {:cpu => deployment.openshift_node_vcpu,
                                   :ram => deployment.openshift_node_ram,
                                   :vda_size => deployment.openshift_node_disk,
                                   :other_disks => [deployment.openshift_storage_size]}
            for i in 1..deployment.openshift_number_ha_nodes do
              vmlauncher = Utils::Fusor::VMLauncher.new(vm_init_params)
              fail _("====== vmlauncher is nil for HA #{i}! ======") unless vmlauncher

              vmlauncher.set_hostname("#{deployment.label.tr('_', '-')}-ose-ha#{i}")
              host = vmlauncher.launch_openshift_vm(ha_vm_launch_params)
              if host.nil?
                fail _("====== Launch OSE HA #{i} VM FAILED! ======")
              else
                deployment.ose_ha_hosts << host
                ::Fusor.log.debug "====== OSE Launched VM Name : #{host.name} ======"
                ::Fusor.log.debug "====== OSE Launched VM IP   : #{host.ip}   ======"
              end
            end

            deployment.save!
            ::Fusor.log.info '====== Leaving OSE Launch run method ======'
          end

          private

          def generate_root_password(deployment)
            ::Fusor.log.info '====== Generating randomized password for root access ======'
            deployment.openshift_root_password = SecureRandom.hex(10)
            deployment.save!
          end

        end
      end
    end
  end
end
