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
      module PrepareOrg
        #Setup and Launch OSE VM
        class UpdateSingleDiskHostgroups < Actions::Fusor::FusorBaseAction
          def humanized_name
            _('Setup and Launch OSE VM')
          end

          def plan(deployment)
            super(deployment)
            plan_self(deployment_id: deployment.id)
          end

          def run
            ::Fusor.log.info '====== Update Single Disk Hostgroups run method ======'
            deployment = ::Fusor::Deployment.find(input[:deployment_id])

            hg_names = []
            hg_names += ['OSD', 'MON'] if deployment.deploy_ceph
            hg_names += ['OpenShift'] if deployment.deploy_openshift

            hg_names.each do |hg_name|
              hostgroup = find_hostgroup(deployment, hg_name)
              os = Operatingsystem.find(hostgroup.operatingsystem_id)
              ptable_name = "Kickstart Single Disk"
              ensure_single_disk_ptable(ptable_name)
              update_ptable_for_os(ptable_name, os.title)
              update_hostgroup_ptable(hostgroup, ptable_name)
            end

            ::Fusor.log.info '====== Leaving Update Single Disk Hostgroups run method ======'
          end

          private

          def find_hostgroup(deployment, name)
            # locate the top-level hostgroup for the deployment...
            # currently, we'll create a hostgroup with the same name as the
            # deployment...
            # Note: you need to scope the query to organization
            parent = ::Hostgroup.where(:name => deployment.label).
                joins(:organizations).
                where("taxonomies.id in (?)", [deployment.organization.id]).first

            # generate the ancestry, so that we can locate the hostgroups
            # based on the hostgroup hierarchy, which assumes:
            #  "Fusor Base"/"My Deployment"
            # Note: there may be a better way in foreman to locate the hostgroup
            if parent
              if parent.ancestry
                ancestry = [parent.ancestry, parent.id.to_s].join('/')
              else
                ancestry = parent.id.to_s
              end
            end

            # locate the engine hostgroup...
            ::Hostgroup.where(:name => name).
                where(:ancestry => ancestry).
                joins(:organizations).
                where("taxonomies.id in (?)", [deployment.organization.id]).first
          end

          def ensure_single_disk_ptable(ptable_name)
            default_name = "Kickstart default"

            if !Ptable.exists?(:name => default_name)
              fail _("====== The expected '#{default_name}' ptable does not exist! ======")
            end

            if Ptable.exists?(:name => ptable_name)
              ::Fusor.log.debug "====== Partition table '#{ptable_name}' already exists! Nothing to do. ====== "
              return
            end

            defaultptable = Ptable.find_by_name(default_name)
            single_disk_table = defaultptable.dup

            layoutstring = single_disk_table.layout.clone
            layoutstring.sub! default_name, ptable_name
            substring = "<% if @host.facts['blockdevices'].split(\",\").include?(\"vda\") -%>\nignoredisk --only-use=vda\n<% else -%>\n"
            substring += "ignoredisk --only-use=sda\n<% end -%>\nautopart"
            layoutstring.sub! "autopart", substring

            single_disk_table.layout = layoutstring
            single_disk_table.name = ptable_name
            single_disk_table.save!
            ::Fusor.log.debug "====== Created a new Partition table '#{ptable_name}' ====== "
          end

          def update_ptable_for_os(ptable_name, os_name)
            ptable = Ptable.find_by_name(ptable_name)
            if ptable.nil?
              fail _("====== ptable name '#{ptable_name}' does not exist! ======")
            end

            os = Operatingsystem.find_by_to_label(os_name)
            if os.nil?
              fail _("====== OS name '#{os_name}' does not exist! ======")
            end

            if os.ptables.exists?(ptable)
              ::Fusor.log.debug "====== The '#{ptable_name}' ptable already exists as option in '#{os_name}'! Nothing to do. ====== "
              return
            end
            os.ptables << ptable
            os.save!
            ::Fusor.log.debug "====== Added '#{ptable_name}' ptable option to '#{os_name}' ====== "
          end

          def update_hostgroup_ptable(hostgroup, ptable_name)
            ptable = Ptable.find_by_name(ptable_name)
            if ptable.nil?
              fail _("====== ptable name '#{ptable_name}' does not exist! ======")
            end

            if hostgroup.nil?
              fail _("====== Hostgroup is nill ======")
            end
            hostgroup.ptable_id = ptable.id
            hostgroup.save!
            ::Fusor.log.debug "====== Updated host group '#{hostgroup}' to use '#{ptable_name}' ptable ====== "
          end
        end
      end
    end
  end
end
