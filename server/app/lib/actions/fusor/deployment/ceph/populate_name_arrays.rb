module Actions
  module Fusor
    module Deployment
      module Ceph
        class PopulateNameArrays < Actions::Fusor::FusorBaseAction

          def humanized_name
            _('Run name array population for Ceph deployment')
          end

          def plan(deployment)
            super(deployment)
            plan_self(deployment_id: deployment.id)
          end

          def run
            ::Fusor.log.debug "====== PopulateNameArrays run method ======"
            deployment = ::Fusor::Deployment.find input[:deployment_id]
            ceph_d = deployment.ceph_deployment
            domain = Domain.find(Hostgroup.find_by_name('Fusor Base').domain_id)

            ceph_d.mon_hosts.each do |host|
              d.mons += [host.name + "." + domain.name]
            end

            ceph_d.deployment.osd_hosts.each do |host|
              d.osds += [host.name + "." + domain.name]
            end

            d.save
            ::Fusor.log.debug "====== Leaving PopulateNameArrays run method ======"
          end
        end
      end
    end
  end
end
