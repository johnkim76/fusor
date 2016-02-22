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

          def run
            ::Fusor.log.debug '====== OSE Launch run method ======'
            deployment = ::Fusor::Deployment.find(input[:deployment_id])
            vmlauncher = Utils::Fusor::VMLauncher.new(deployment, "ose", "RHEV" )
            compute_attrs = vmlauncher.create_compute_profile.vm_attrs
            hg_id = Hostgroup.where(name: deployment.label).first.id
            host_attrs = {"ptable_id" => Ptable.find { |p| p["name"] == "Kickstart default" }.id,
                          "domain_id" => 1,
                          "root_pass" => "smartvm1",
                          "mac" => "admin",
                          "build" => "0",
                          "hostgroup_id" => hg_id,
                          #using a compute_profile_id the vm does not start, so for now merge with attr. 
                          "compute_attributes" => {"start" => "1"}.with_indifferent_access.merge(compute_attrs)}
            vmlauncher.update_host_attrs(host_attrs)
            host = vmlauncher.launch_vm
            
            #deployment.ose_address  = host.ip
            #deployment.ose_hostname = host.name
            #deployment.save!
            ::Fusor.log.debug '====== Leaving OSE Launch run method ======'
          end

          def ose_launch_completed
            ::Fusor.log.info 'OSE Launch Completed'
          end

          def ose_launch_failed
            fail _('OSE Launch failed')
          end
        end
      end
    end
  end
end
