module Actions
  module Fusor
    module Deployment
      module Ceph
        class TriggerAnsibleRun < Actions::Fusor::FusorBaseAction

          def humanized_name
            _('Trigger ansible run for Ceph deployment')
          end

          def plan(deployment)
            super(deployment)
            plan_self(deployment_id: deployment.id)
          end

          def run
            ::Fusor.log.debug "====== TriggerAnsibleRun run method ======"
            deployment = ::Fusor::Deployment.find input[:deployment_id]
            inventory = generate_inventory(deployment)
            config_dir = "#{Rails.root}/tmp/ceph-ansible/#{deployment.label}"
            environment = get_environment(deployment, config_dir)
            distribute_public_key(deployment)
            default_module_path = "~"

            unless Dir.exist?(config_dir)
              FileUtils.mkdir_p(config_dir)
            end
            File.open(config_dir + '/inventory', 'w') { |file| file.write(inventory) }

            if deployment.ceph_deployment.configure_rhsm
              rhsm_mon_vars = generate_rhsm_mon_vars(deployment)
              rhsm_osd_vars = generate_rhsm_osd_vars(deployment)
              rhsm_mon_playbook = "/usr/share/ansible-ceph-extras/rhsm_mon.yaml"
              rhsm_osd_playbook = "/usr/share/ansible-ceph-extras/rhsm_osd.yaml"
              trigger_ansible_run(rhsm_mon_playbook, rhsm_mon_vars, config_dir, environment, default_module_path)
              trigger_ansible_run(rhsm_osd_playbook, rhsm_osd_vars, config_dir, environment, default_module_path)
            end

            if deployment.ceph_deployment.configure_firewall
              fwd_vars = {"dummy" => "" }
              fwd_mon_playbook = "/usr/share/ansible-ceph-extras/fwd_mon.yaml"
              fwd_osd_playbook = "/usr/share/ansible-ceph-extras/fwd_osd.yaml"
              trigger_ansible_run(fwd_mon_playbook, fwd_vars, config_dir, environment, default_module_path)
              trigger_ansible_run(fwd_osd_playbook, fwd_vars, config_dir, environment, default_module_path)
            end

            if deployment.ceph_deployment.configure_ntp
              ntp_vars = { "ntp_host" => Setting['foreman_url'].gsub(/^http:\/\//, "") }
              ntp_playbook = "/usr/share/ansible-ceph-extras/ntp.yaml"
              ntp_role_path = "/usr/share/ansible-ntp"
              trigger_ansible_run(ntp_playbook, ntp_vars, config_dir, environment, ntp_role_path)
            end

            ceph_vars = generate_ceph_vars(deployment, config_dir)
            ceph_playbook = "/usr/share/ceph-ansible/site.yml.sample"
            ceph_module_path = "/usr/share/ceph-ansible"
            trigger_ansible_run(ceph_playbook, ceph_vars, config_dir, environment, ceph_module_path)

            ::Fusor.log.debug "====== Leaving TriggerAnsibleRun run method ======"
          end

          private

          def generate_inventory(deployment)
            ["[mons]",
             deployment.ceph_deployment.mons.join("\n"),
             "[osds]",
             deployment.ceph_deployment.osds.join("\n")].join("\n")
          end

          def generate_rhsm_mon_vars(deployment)
            {
              "activationkey" => "MON-#{deployment.label}-MON",
              "server_hostname" => Setting['foreman_url'].gsub(/^http:\/\//, "")
            }
          end

          def generate_rhsm_osd_vars(deployment)
            {
              "activationkey" => "OSD-#{deployment.label}-OSD",
              "server_hostname" => Setting['foreman_url'].gsub(/^http:\/\//, "")
            }
          end

          def generate_ceph_vars(deployment)
            ceph = deployment.ceph_deployment
            {
              "ceph_stable_rh_storage" => true,
              "ceph_stable_rh_storage_cdn_install" => true,
              "generate_fsid" => true,
              "cephx" => true,
              "monitor_interface" => ceph.monitor_interface,
              "journal_size" => ceph.journal_size,
              "public_network" => ceph.public_network,
              "calamari" => ceph.calamari,
              "crush_location" => ceph.crush_location,
              "osd_crush_location" => ceph.osd_crush_location,
              "devices" => ceph.osd_devicess,
              "journal_collocation" => ceph.journal_collocation,
              "journal_device" => ceph.journal_device
            }
          end

          def get_environment(deployment, config_dir)
            {
              'ANSIBLE_HOST_KEY_CHECKING' => 'False',
              'ANSIBLE_LOG_PATH' => "#{::Fusor.log_file_dir(deployment.label, deployment.id)}/ansible.log",
              'ANSIBLE_RETRY_FILES_ENABLED' => "False",
              'ANSIBLE_SSH_CONTROL_PATH' => "/tmp/%%h-%%r",
              'ANSIBLE_ASK_SUDO_PASS' => "False",
              'ANSIBLE_PRIVATE_KEY_FILE' => ::Utils::Fusor::SSHKeyUtils.new(deployment).get_ssh_private_key_path,
              'ANSIBLE_CONFIG' => config_dir,
              'HOME' => config_dir
            }
          end

          def distribute_public_key(deployment)
            keyutils = Utils::Fusor::SSHKeyUtils.new(deployment)

            deployment.ceph_deployment.mons.each do |host|
              distribute_key_to_host keyutils, host, deployment.ceph_deployment.ssh_pass
            end

            deployment.ceph_deployment.osds.each do |host|
              distribute_key_to_host keyutils, host, deployment.ceph_deployment.ssh_pass
            end
          end


          def distribute_key_to_host(keyutils, host, password)
            time_to_sleep = 30
            tries ||= 10
            keyutils.copy_pub_key_to_auth_keys(host, "root", password)
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::SCP::Error
            ::Fusor.log.debug "======= SSH is not yet available on host #{host}, #{tries - 1} retries remaining ======"
            if (tries -= 1) > 0
              ::Fusor.log.debug "====== Sleeping for #{time_to_sleep} seconds"
              sleep time_to_sleep
              retry
            else
              raise
            end
          end

          def trigger_ansible_run(playbook, vars, config_dir, environment, path)
            debug_log = SETTINGS[:fusor][:system][:logging][:ansible_debug]
            extra_args = ""
            if debug_log
              environment['ANSIBLE_KEEP_REMOTE_FILES'] = 'True'
              extra_args = '-vvvv '
            end

            cmd = "pushd #{path} && ansible-playbook #{playbook} -i #{config_dir}/inventory -e '#{vars.to_json}' -u root #{extra_args} && popd"
            status, output = ::Utils::Fusor::CommandUtils.run_command(cmd, true, environment)

            if status != 0
              fail _("ceph returned a non-zero return code\n#{output.gsub('\n', "\n")}")
            else
              ::Fusor.log.debug(output)
              status
            end
          end
        end
      end
    end
  end
end
