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
      module Ceph
        class Deploy < Actions::Fusor::FusorBaseAction
          def humanized_name
            _("Deploy Ceph")
          end

          def plan(deployment)
            super(deployment)
            sequence do
              if deployment.ceph_deployment.poc
                plan_action(::Actions::Fusor::Deployment::Ceph::PopulateNameArrays, deployment)

                hosts_with_hostgroups = deployment.ceph_deployment.mon_hosts.map { |h| [h, 'MON'] } +
                  deployment.ceph_deployment.osd_hosts.map { |h| [h, 'OSD'] }

                hosts_with_hostgroups.each do |host, hostgroup|
                  plan_action(::Actions::Fusor::Host::TriggerProvisioning,
                            deployment,
                            hostgroup,
                            host)
                end

                concurrence do
                  hosts_with_hostgroups.each do |host, hostgroup|
                    plan_action(::Actions::Fusor::Host::WaitUntilProvisioned, host.id)
                  end
                end
              end

              plan_action(::Actions::Fusor::Deployment::Ceph::TriggerAnsibleRun, deployment)

              if deployment.deploy_openstack
                #plan_action(::Actions::Fusor::Deployment::Ceph::CreateOSPCredentials, deployment)
              end
            end
          end
        end
      end
    end
  end
end
