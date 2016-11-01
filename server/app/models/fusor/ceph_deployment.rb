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
  class CephDeployment < ActiveRecord::Base
    CEPH_PARAM_HASH = {
        ssh_user: 'ssh_user',
        ssh_pass: 'ssh_pass',
        poc: 'poc',
        mons: 'mons',
        osds: 'osds',
        monitor_interface: 'monitor_interface',
        journal_size: 'journal_size',
        public_network: 'public_network',
        calamari: 'calamari',
        journal_collocation: 'journal_collocation',
        osd_devices: 'osd_devices',
        journal_device: 'journal_device',
        crush_location: 'crush_location',
        osd_crush_location: 'osd_crush_location'
    }

    attr_accessor :warnings

    after_initialize :setup_warnings
    #validates_with Fusor::Validators::OpenstackDeploymentValidator, on: :update

    has_one :deployment, :class_name => "Fusor::Deployment"
    has_many :mon_deployment_hosts, -> { where(:deployment_host_type => 'mon') }, :class_name => "Fusor::DeploymentHost"
    has_many :mon_hosts, :through => :mon_deployment_hosts, :class_name => "::Host::Base", :source => :discovered_host
    has_many :osd_deployment_hosts, -> { where(:deployment_host_type => 'osd') }, :class_name => "Fusor::DeploymentHost"
    has_many :osd_hosts, :through => :osd_deployment_hosts, :class_name => "::Host::Base", :source => :discovered_host

    def setup_warnings
      self.warnings = []
    end

  end
end
