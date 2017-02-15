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
  class CephDeploymentHost < ActiveRecord::Base
    # if we want to envorce discovered host uniqueness uncomment this line
    #validates :discovered_host_id, uniqueness: { :message => _('This Host is already an RHV Hypervisor for a different deployment') }
    belongs_to :discovered_host, :class_name => "::Host::Base"
    belongs_to :ceph_deployment, :class_name => "Fusor::CephDeployment"
  end
end
