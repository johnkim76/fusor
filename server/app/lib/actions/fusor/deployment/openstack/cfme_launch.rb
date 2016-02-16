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
      module OpenStack
        #Setup and Launch CFME VM
        class CfmeLaunch < Actions::Fusor::FusorBaseAction
          def humanized_name
            _('Setup and Launch CFME VM')
          end

          def plan(deployment)
            super(deployment)
            plan_self(deployment_id: deployment.id)
          end

          def run
            ::Fusor.log.debug '====== CFME Launch run method ======'
            deployment = ::Fusor::Deployment.find(input[:deployment_id])            
            vmlauncher = Utils::Fusor::VMLauncher.new(deployment, "cfme", "RHOS")
            vmlauncher.create_compute_profile
            host_attrs = {"domain_id" => 1,
                          "root_pass" => "smartvm",
                          "mac" => "admin",
                          "provision_method" => "image",
                          "build" => 1,
                          "is_owned_by" => "3-Users",
                          "compute_profile_id" => ComputeProfile.find_by_name("#{deployment.label}-cfme").id}
            vmlauncher.update_host_attrs(host_attrs)
            host = vmlauncher.launch_vm
            deployment.cfme_address  = host.ip
            deployment.cfme_hostname = host.name
            deployment.save!
            ::Fusor.log.debug '====== Leaving Launc Upload run method ======'
          end

          def cfme_launch_completed
            ::Fusor.log.info 'CFME Launch Completed'
          end

          def cfme_launch_failed
            fail _('CFME Launch failed')
          end
        end
      end
    end
  end
end
