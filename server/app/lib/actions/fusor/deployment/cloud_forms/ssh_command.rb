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

module Actions::Fusor::Deployment::CloudForms
  class SshCommand < Actions::Fusor::FusorBaseAction
    def humanized_name
      _("SSH and run an arbitrary command on the CFME")
    end

    def plan(deployment, cmd)
      super(deployment)
      plan_self(deployment_id: deployment.id,
                cmd: cmd)
    end

    def run
      ::Fusor.log.debug "================ SshCommand run method ===================="

      deployment = ::Fusor::Deployment.find(input[:deployment_id])

      ssh_host = deployment.cfme_rhv_address || deployment.cfme_osp_address
      ssh_username = "root"
      ssh_password = deployment.cfme_root_password

      client = Utils::Fusor::SSHConnection.new(ssh_host, ssh_username, ssh_password)
      client.on_complete(lambda { ssh_command_completed })
      client.on_failure(lambda { ssh_command_failed })
      client.execute(input[:cmd])

      ::Fusor.log.debug "================ Leaving SshCommand run method ===================="
    end

    def ssh_command_completed
      ::Fusor.log.info "Command succeeded: " + input[:cmd]
    end

    def ssh_command_failed
      fail _("Command failed: " + input[:cmd])
    end
  end
end
