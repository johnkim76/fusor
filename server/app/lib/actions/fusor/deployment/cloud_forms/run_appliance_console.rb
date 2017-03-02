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

require 'fusor/password_filter'

module Actions
  module Fusor
    module Deployment
      module CloudForms
        class RunApplianceConsole < Actions::Fusor::FusorBaseAction
          def humanized_name
            _("Run CloudForms Appliance Console")
          end

          def plan(deployment, primary_appliance)
            super(deployment)
            plan_self(deployment_id: deployment.id, primary_appliance: primary_appliance)
          end

          def run
            ::Fusor.log.debug "================ RunApplianceConsole run method ===================="
            deployment = ::Fusor::Deployment.find(input[:deployment_id])

            script_dir = "/usr/share/fusor_ovirt/bin/"
            db_password = deployment.cfme_db_password
            ssh_user = "root"
            if input[:primary_appliance] == 'RHEV'
              cfme_address = deployment.cfme_rhv_address
              secondary_address = deployment.cfme_osp_address
            else
              cfme_address = deployment.cfme_osp_address
              secondary_address = deployment.cfme_rhv_address
            end

            ::Fusor.log.warn "using cfme_root_password"
            ssh_password = deployment.cfme_root_password

            cmd = "#{script_dir}miq_run_appliance_console.py "\
                  "--miq_ip #{cfme_address} "\
                  "--ssh_user #{ssh_user} "\
                  "--ssh_pass #{ssh_password} "\
                  "--db_password #{db_password}"

            status, output = run_command(cmd)
            fail _("Unable to run appliance console: %{output}") % { :output => output } unless status == 0

            if secondary_address
              cmd = "#{script_dir}miq_run_appliance_console.py "\
                  "--miq_ip #{secondary_address} "\
                  "--ssh_user #{ssh_user} "\
                  "--ssh_pass #{ssh_password} "\
                  "--db_password #{db_password}"\
                  "--primary_appliance #{cfme_address}"

              status, output = run_command(cmd)
              fail _("Unable to run appliance console: %{output}") % { :output => output } unless status == 0

              # TODO: observing issues with running the appliance console using SSHConnection; therefore, temporarily
              # commenting out and using the approach above which will run it from a python script
              #client = Utils::Fusor::SSHConnection.new(cfme_address, ssh_user, ssh_password)
              #client.on_complete(lambda { run_appliance_console_completed })
              #client.on_failure(lambda { run_appliance_console_failed })
              #cmd = "appliance_console_cli --region 1 --internal --force-key -p #{db_password} --verbose"
              #client.execute(cmd)
            end
            ::Fusor.log.debug "================ Leaving RunApplianceConsole run method ===================="
          end

          # TODO: temporarily commenting out the SSHConnection callbacks.  See above.
          #def run_appliance_console_completed
          #  ::Fusor.log.warn "the appliance console successfully ran on the node"
          #  puts "the appliance console successfully ran on the node"
          #  sleep 300 # TODO: pause while the appliance web ui comes up...
          #end
          #
          #def run_appliance_console_failed
          #  fail _("Failed to run appliance console")
          #end

          private

          def run_command(cmd)
            max_try = 30
            retries = 0
            status = 1

            ::Fusor.log.info "Running: #{PasswordFilter.filter_passwords(cmd.clone)}"
            while (status != 0) && (retries < max_try)
              status, output = Utils::Fusor::CommandUtils.run_command(cmd)
              retries += 1
              ::Fusor.log.warn "Attempt [#{retries} of #{max_try}] of the above command FAILED!... Retrying..." unless status == 0
              sleep 30 unless status == 0
            end

            ::Fusor.log.debug "Status: #{status}, output: #{output}"
            return status, output
          end
        end
      end
    end
  end
end
