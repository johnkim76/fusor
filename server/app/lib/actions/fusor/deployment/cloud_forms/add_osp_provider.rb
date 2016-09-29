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
      module CloudForms
        class AddOspProvider < Actions::Fusor::FusorBaseAction
          def humanized_name
            _("Add OSP Provider")
          end

          def plan(deployment)
            super(deployment)
            plan_self(deployment_id: deployment.id)
          end

          def run
            ::Fusor.log.debug "================ AddOspProvider run method ===================="
            deployment = ::Fusor::Deployment.find(input[:deployment_id])
            cfme_addresses = [deployment.cfme_rhv_address, deployment.cfme_osp_address]
            cfme_addresses.compact

            undercloud = {
              :name => "#{deployment.label}-RHOS-Director",
              :type => "ManageIQ::Providers::Openstack::InfraManager",
              :security_protocol => 'non-ssl',
              :hostname => deployment.openstack_deployment.undercloud_ip_address,
              :port => "5000",
              :zone_id => "1000000000001",
              :credentials => {
                :userid => 'admin',
                :password => deployment.openstack_deployment.undercloud_admin_password
              }
            }

            ::Fusor.log.info "Adding Director #{undercloud[:name]} to CFME."
            cfme_addresses.each do |cfme_address|
              uc = Utils::CloudForms::AddProvider.add(cfme_address, undercloud, deployment)

              overcloud = {
                :name => "#{deployment.label}-RHOS",
                :type => "ManageIQ::Providers::Openstack::CloudManager",
                :hostname => deployment.openstack_deployment.overcloud_hostname,
                :port => "13000",
                :zone_id => "1000000000001",
                :credentials => {
                  :userid => 'admin',
                  :password => deployment.openstack_deployment.overcloud_password
                }
              }

              #Prevent failed deployment if undercloud isn't created due to BZ#1351253
              overcloud[:provider_id] = JSON.parse(uc.to_s)["results"].first["provider_id"] if uc

              ::Fusor.log.info "Adding OSP provider #{overcloud[:name]} to CFME."
              Utils::CloudForms::AddProvider.add(cfme_address, overcloud, deployment)
            end
            ::Fusor.log.debug "================ Leaving AddOspProvider run method ===================="
          end
        end
      end
    end
  end
end
