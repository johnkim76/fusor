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

module Fusor
  class Deployment < ActiveRecord::Base

    # on update because we don't want to validate the empty object when
    # it is first created
    validates_with Fusor::Validators::DeploymentValidator, on: :update
    validates_associated :ceph_deployment, on: :update
    validates_associated :openstack_deployment, on: :update

    belongs_to :organization
    belongs_to :lifecycle_environment, :class_name => "Katello::KTEnvironment"

    belongs_to :ceph_deployment, :class_name => "Fusor::CephDeployment", dependent: :destroy
    belongs_to :openstack_deployment, :class_name => "Fusor::OpenstackDeployment", dependent: :destroy

    validates :name, :presence => true, :uniqueness => {:scope => :organization_id}
    validates :label, :presence => true, :uniqueness => {:scope => :organization_id}
    validates :organization_id, :presence => true
    validates :rhev_root_password, :allow_blank => true, :length => {:minimum => 8, :message => _('should be 8 characters or more')}
    validates :cfme_root_password, :allow_blank => true, :length => {:minimum => 8, :message => _('should be 8 characters or more')}
    validates :cfme_admin_password, :allow_blank => true, :length => {:minimum => 8, :message => _('should be 8 characters or more')}
    validates :openshift_user_password, :allow_blank => true, :length => {:minimum => 8, :message => _('should be 8 characters or more')}

    validates :rhev_cluster_name, :allow_blank => true, :length => {:maximum => 40, :message => _('should be 40 characters or less')}

    belongs_to :rhev_engine_host, :class_name => "::Host::Base", :foreign_key => :rhev_engine_host_id
    # if we want to envorce discovered host uniqueness uncomment this line
    #validates :rhev_engine_host_id, uniqueness: { :message => _('This Host is already an RHV Engine for a different deployment') }
    has_many :rhev_hypervisor_hosts, :class_name => "::Host::Base", :through => :deployment_hypervisor_hosts, :source => :discovered_host
    validates_with ::Katello::Validators::KatelloNameFormatValidator, :attributes => :name

    #TODO need to rename to hypervisor_hosts
    belongs_to :discovered_host, :class_name => "::Host::Base", :foreign_key => :rhev_engine_host_id
    has_many :deployment_hypervisor_hosts, -> { where(:deployment_host_type => 'rhev_hypervisor') }, :class_name => "Fusor::DeploymentHost"
    has_many :discovered_hosts, :through => :deployment_hypervisor_hosts, :class_name => "::Host::Base", :source => :discovered_host
    has_many :ose_deployment_master_hosts, -> { where(:deployment_host_type => 'ose_master') }, :class_name => "Fusor::DeploymentHost"
    has_many :ose_master_hosts, :through => :ose_deployment_master_hosts, :class_name => "::Host::Base", :source => :discovered_host
    has_many :ose_deployment_worker_hosts, -> { where(:deployment_host_type => 'ose_worker') }, :class_name => "Fusor::DeploymentHost"
    has_many :ose_worker_hosts, :through => :ose_deployment_worker_hosts, :class_name => "::Host::Base", :source => :discovered_host
    has_many :ose_deployment_ha_hosts, -> { where(:deployment_host_type => 'ose_ha') }, :class_name => "Fusor::DeploymentHost"
    has_many :ose_ha_hosts, :through => :ose_deployment_ha_hosts, :class_name => "::Host::Base", :source => :discovered_host
    alias_attribute :discovered_host_id, :rhev_engine_host_id
    attr_accessor :foreman_task_id

    has_many :subscriptions, :class_name => "Fusor::Subscription", :foreign_key => :deployment_id, dependent: :destroy
    has_many :introspection_tasks, :class_name => 'Fusor::IntrospectionTask'

    belongs_to :foreman_task, :class_name => "::ForemanTasks::Task", :foreign_key => :foreman_task_uuid

    after_initialize :setup_warnings
    before_validation :update_label, :ensure_openstack_deployment, :ensure_ceph_deployment,
                      :ensure_ssh_keys, on: :create  # we validate on create, so we need to do it before those validations
    before_save :update_label, :ensure_openstack_deployment, :ensure_ceph_deployment, on: :update # but we don't validate on update, so we need to call before_save

    scoped_search :on => [:id, :name, :updated_at], :complete_value => true
    scoped_search :in => :organization, :on => :name, :rename => :organization
    scoped_search :in => :lifecycle_environment, :on => :name, :rename => :lifecycle_environment
    scoped_search :in => :foreman_task, :on => :state, :rename => :status

    # used by ember-data for .find('model', {id: [1,2,3]})
    scope :by_id, proc { |n| where(:id => n) if n.present? }

    DEPLOYMENT_TYPES = [:rhev, :cfme, :openstack, :openshift, :ceph]

    attr_accessor :warnings

    def setup_warnings
      self.warnings = []
    end

    def deploy?(deploy_type)
      fail _("Invalid deployment type: %s") % deploy_type unless DEPLOYMENT_TYPES.include?(deploy_type.to_sym)
      send("deploy_#{deploy_type}")
    end

    def is_started?
      foreman_task_uuid.present?
    end

    def openshift_ha?
      openshift_number_master_nodes > 1
    end

    def openshift_number_ha_nodes
      openshift_ha? ? 2 : 0
    end

    def openshift_number_infra_nodes
      openshift_ha? ? 2 : 0
    end

    def rhev_nested_virt?
      rhev_hypervisor_hosts.any? { |host| host.facts.try(:[], "is_virtual") == 'true' }
    end

    protected

    def update_label
      self.label = name ? name.downcase.gsub(/[^a-z0-9_]/i, "_") : nil
    end

    def ensure_openstack_deployment
      if deploy_openstack?
        self.openstack_deployment ||= Fusor::OpenstackDeployment.create
      else
        self.openstack_deployment.destroy if openstack_deployment
      end
      true
    end

    def ensure_ssh_keys
      if self.ssh_private_key.nil? || self.ssh_private_key.empty?
        keys = ::Utils::Fusor::SSHKeyUtils.new(self).generate_ssh_keys
        self.ssh_private_key = keys[:private_key]
        self.ssh_public_key = keys[:public_key]
      end
    end

    def ensure_ceph_deployment
      if deploy_ceph?
        self.ceph_deployment ||= Fusor::CephDeployment.create
      else
        self.ceph_deployment.destroy if ceph_deployment
      end
      true
    end
  end
end
