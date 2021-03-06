require 'test_plugin_helper'

module Fusor
  class Api::V21::OpenstackDeploymentsControllerTest < ActionController::TestCase
    describe 'restful resource requests' do
      def setup
        @openstack_deployment = fusor_openstack_deployments(:osp)
        setup_fusor_routes
        @controller = ::Fusor::Api::V21::OpenstackDeploymentsController.new
      end

      test 'index request should return array of openstack_deployments' do
        body = JSON.parse(get(:index).body)
        assert_response :success
        openstack_deployment_found = body['openstack_deployments'].any? { |osp_d| osp_d['id'] == @openstack_deployment.id }
        assert openstack_deployment_found, 'Response was not correct, did not include openstack_deployment'
      end

      test 'show request should return the openstack deployment' do
        body = JSON.parse(get(:show, :id => @openstack_deployment.id).body)
        assert_response :success
        assert_equal @openstack_deployment.id, body['openstack_deployment']['id'], 'Response was not correct, OpenStack deployment was not returned'
      end

      test 'update request should successfully update openstack deployment' do
        new_overcloud_password = 'testing'
        body = JSON.parse(put(:update, :id => @openstack_deployment.id, openstack_deployment: {overcloud_password: new_overcloud_password}).body)
        assert_response :success
        assert_equal new_overcloud_password, body['openstack_deployment']['overcloud_password'], 'Response was not correct, OpenStack deployment was not updated'
        @openstack_deployment.reload
        assert_equal @openstack_deployment.overcloud_password, new_overcloud_password, 'Update not successful. OpenStack deployment record was not updated'
      end

      test 'create request should successfully create OpenStack deployment' do
        previous_count = OpenstackDeployment.count
        body = JSON.parse(post(:create).body)
        assert_equal previous_count + 1, OpenstackDeployment.count, 'The number of OpenStack deployments should increase by one if we create a new one'
        assert_response :success
        assert_not_nil body['openstack_deployment']['id'], 'Response was not correct, did not return OpenStack deployment'
        assert_not_nil OpenstackDeployment.find body['openstack_deployment']['id']
      end

      test 'delete request should successfully delete deployment' do
        previous_count = OpenstackDeployment.count
        JSON.parse(delete(:destroy, :id => @openstack_deployment.id).body)
        assert_equal previous_count - 1, OpenstackDeployment.count, 'The number of OpenStack deployments should decrease by one if we delete one'
        assert_response :success
        assert_empty OpenstackDeployment.where(id: @openstack_deployment.id)
      end
    end

    describe 'sync_openstack' do
      def build_overcloud_edit_plan_parameters(openstack_deployment)
        {
          'CloudName' =>                "#{openstack_deployment.deployment.label.tr('_', '-')}-overcloud.#{Domain.find(Hostgroup.find_by_name('Fusor Base').domain_id)}",
          'SSLRootCertificate'          => 'x',
          'SSLCertificate'              => 'y',
          'SSLKey'                      => 'z',
          'rhel_reg_sat_repo'           => 'rhel-7-server-satellite-tools-6.2-rpms',
          'rhel_reg_org'                => 'Default_Organization',
          'rhel_reg_method'             => 'satellite',
          'rhel_reg_sat_url'            => Setting[:foreman_url],
          'rhel_reg_activation_key'     => "OpenStack_Undercloud-#{openstack_deployment.deployment.label}-OpenStack_Undercloud",
          'NeutronPublicInterface'      =>  openstack_deployment.overcloud_ext_net_interface,
          'NovaComputeLibvirtType'      =>  openstack_deployment.overcloud_libvirt_type,
          'AdminPassword'               =>  openstack_deployment.overcloud_password,
          'OvercloudComputeFlavor'      =>  openstack_deployment.overcloud_compute_flavor,
          'ComputeCount'                =>  openstack_deployment.overcloud_compute_count,
          'OvercloudControlFlavor'      =>  openstack_deployment.overcloud_controller_flavor,
          'ControllerCount'             =>  openstack_deployment.overcloud_controller_count,
          'OvercloudCephStorageFlavor'  =>  openstack_deployment.overcloud_ceph_storage_flavor,
          'CephStorageCount'            =>  openstack_deployment.overcloud_ceph_storage_count,
          'OvercloudBlockStorageFlavor' =>  openstack_deployment.overcloud_block_storage_flavor,
          'BlockStorageCount'           =>  openstack_deployment.overcloud_block_storage_count,
          'OvercloudSwiftStorageFlavor' =>  openstack_deployment.overcloud_object_storage_flavor,
          'ObjectStorageCount'          =>  openstack_deployment.overcloud_object_storage_count
        }
      end

      def build_ceph_edit_plan_parameters(openstack_deployment)
        {
          'CephExternalMonHost'         => openstack_deployment.ceph_ext_mon_host,
          'CephClusterFSID'             => openstack_deployment.ceph_cluster_fsid,
          'CephClientUserName'          => openstack_deployment.ceph_client_username,
          'CephClientKey'               => openstack_deployment.ceph_client_key,
          'NovaRbdPoolName'             => openstack_deployment.nova_rbd_pool_name,
          'CinderRbdPoolName'           => openstack_deployment.cinder_rbd_pool_name,
          'GlanceRbdPoolName'           => openstack_deployment.glance_rbd_pool_name
        }
      end

      def build_get_plan_parameters(openstack_deployment)
        {
          'CloudName'                   => {'Default' => "#{openstack_deployment.deployment.label.tr('_', '-')}-overcloud.#{Domain.find(Hostgroup.find_by_name('Fusor Base').domain_id)}"},
          'SSLRootCertificate'          => {'Default' => 'x'},
          'SSLCertificate'              => {'Default' => 'y'},
          'SSLKey'                      => {'Default' => 'z'},
          'rhel_reg_sat_repo'           => {'Default' => 'rhel-7-server-satellite-tools-6.2-rpms'},
          'rhel_reg_org'                => {'Default' => 'Default_Organization'},
          'rhel_reg_method'             => {'Default' => 'satellite'},
          'rhel_reg_sat_url'            => {'Default' => Setting[:foreman_url]},
          'rhel_reg_activation_key'     => {'Default' => "OpenStack_Undercloud-#{openstack_deployment.deployment.label}-OpenStack_Undercloud"},
          'NeutronPublicInterface'      => {'Default' => openstack_deployment.overcloud_ext_net_interface},
          'NovaComputeLibvirtType'      => {'Default' => openstack_deployment.overcloud_libvirt_type},
          'AdminPassword'               => {'Default' => openstack_deployment.overcloud_password},
          'OvercloudComputeFlavor'      => {'Default' => openstack_deployment.overcloud_compute_flavor},
          'ComputeCount'                => {'Default' => openstack_deployment.overcloud_compute_count},
          'OvercloudControlFlavor'      => {'Default' => openstack_deployment.overcloud_controller_flavor},
          'ControllerCount'             => {'Default' => openstack_deployment.overcloud_controller_count},
          'OvercloudCephStorageFlavor'  => {'Default' => openstack_deployment.overcloud_ceph_storage_flavor},
          'CephStorageCount'            => {'Default' => openstack_deployment.overcloud_ceph_storage_count},
          'OvercloudBlockStorageFlavor' => {'Default' => openstack_deployment.overcloud_block_storage_flavor},
          'BlockStorageCount'           => {'Default' => openstack_deployment.overcloud_block_storage_count},
          'OvercloudSwiftStorageFlavor' => {'Default' => openstack_deployment.overcloud_object_storage_flavor},
          'ObjectStorageCount'          => {'Default' => openstack_deployment.overcloud_object_storage_count},
          'CephExternalMonHost'         => {'Default' => openstack_deployment.ceph_ext_mon_host},
          'CephClusterFSID'             => {'Default' => openstack_deployment.ceph_cluster_fsid},
          'CephClientUserName'          => {'Default' => openstack_deployment.ceph_client_username},
          'CephClientKey'               => {'Default' => openstack_deployment.ceph_client_key},
          'NovaRbdPoolName'             => {'Default' => openstack_deployment.nova_rbd_pool_name},
          'CinderRbdPoolName'           => {'Default' => openstack_deployment.cinder_rbd_pool_name},
          'GlanceRbdPoolName'           => {'Default' => openstack_deployment.glance_rbd_pool_name}
        }
      end

      def build_get_plan_environments(ceph_enabled)
        [
          [
            "Storage",
            {
              "environment_groups" => [
                {
                  "description" => "Enable the use of an externally managed Ceph cluster\n",
                  "environments" => [
                    {
                      "enabled" => ceph_enabled,
                      "requires" => [
                        "overcloud-resource-registry-puppet.yaml"
                      ],
                      "description" => nil,
                      "file" => "environments/puppet-ceph-external.yaml",
                      "title" => "Externally managed Ceph"
                    }
                  ],
                  "title" => "Externally managed Ceph"
                }
              ],
              "description" => nil,
              "title" => "Storage"
            }
          ]
        ]
      end

      def setup
        @openstack_deployment = fusor_openstack_deployments(:osp)
        @ceph_openstack_deployment = fusor_openstack_deployments(:osp_ceph)
        setup_fusor_routes
        @controller = ::Fusor::Api::V21::OpenstackDeploymentsController.new

        @overcloud_edit_parameters = build_overcloud_edit_plan_parameters(@openstack_deployment)
        @overcloud_get_parameters = build_get_plan_parameters(@openstack_deployment)

        @ceph_edit_parameters = build_overcloud_edit_plan_parameters(@ceph_openstack_deployment).merge(build_ceph_edit_plan_parameters(@ceph_openstack_deployment))
        @ceph_get_parameters = build_get_plan_parameters(@ceph_openstack_deployment)

        @overcloud_edit_environments = {'environments/puppet-ceph-external.yaml' => false, 'environments/rhel-registration.yaml' => true,
                                        'environments/enable-tls.yaml' => true, 'environments/inject-trust-anchor.yaml' => true}
        @overcloud_get_environments = build_get_plan_environments(false)

        @ceph_edit_environments = {'environments/puppet-ceph-external.yaml' => true, 'environments/rhel-registration.yaml' => true,
                                   'environments/enable-tls.yaml' => true, 'environments/inject-trust-anchor.yaml' => true}
        @ceph_get_environments = build_get_plan_environments(true)
      end

      test 'sync_openstack should sync overcloud parameters and environments when ceph is disabled' do
        Utils::Fusor::OvercloudSSL.any_instance.stubs(:gen_certs).returns({'ca' => 'x', 'cert' => 'y', 'key' => 'z'})
        Overcloud::UndercloudHandle.any_instance
          .expects(:list_stacks).returns([])
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_environments)
          .with('overcloud', @overcloud_edit_environments)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_parameters)
          .with('overcloud', @overcloud_edit_parameters)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_environments)
          .returns(@overcloud_get_environments)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_parameters)
          .returns(@overcloud_get_parameters)
        JSON.parse(post(:sync_openstack, :id => @openstack_deployment.id).body)
        assert_response :success
      end


      test 'sync_openstack should sync overcloud parameters and environments when ceph is enabled' do
        Utils::Fusor::OvercloudSSL.any_instance.expects(:gen_certs).returns({'ca' => 'x', 'cert' => 'y', 'key' => 'z'})
        Overcloud::UndercloudHandle.any_instance
          .expects(:list_stacks).returns([])
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_environments)
          .with('overcloud', @ceph_edit_environments)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_parameters)
          .with('overcloud', @ceph_edit_parameters)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_environments)
          .returns(@ceph_get_environments)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_parameters)
          .returns(@ceph_get_parameters)

        JSON.parse(post(:sync_openstack, :id => @ceph_openstack_deployment.id).body)
        assert_response :success
      end

      test 'sync_openstack should fail if overcloud is deployed' do
        Overcloud::UndercloudHandle.any_instance
          .expects(:list_stacks)
          .returns(['overcloud'])
          .once
        JSON.parse(post(:sync_openstack, :id => @openstack_deployment.id).body)
        assert_response 422
      end

      test 'sync_openstack should return an error if environments are not synchronized when ceph is disabled' do
        Utils::Fusor::OvercloudSSL.any_instance.expects(:gen_certs).returns({'ca' => 'x', 'cert' => 'y', 'key' => 'z'})
        bad_environments = build_get_plan_environments(true)

        Overcloud::UndercloudHandle.any_instance
          .expects(:list_stacks).returns([])
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_environments)
          .with('overcloud', @overcloud_edit_environments)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_parameters)
          .with('overcloud', @overcloud_edit_parameters)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_environments)
          .returns(bad_environments)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_parameters)
          .returns(@overcloud_get_parameters)

        body = JSON.parse(post(:sync_openstack, :id => @openstack_deployment.id).body)
        assert_response 500
        assert_not_empty body['errors']
      end

      test 'sync_openstack should return an error if environments are not synchronized when ceph is enabled' do
        Utils::Fusor::OvercloudSSL.any_instance.expects(:gen_certs).returns({'ca' => 'x', 'cert' => 'y', 'key' => 'z'})
        bad_environments = build_get_plan_environments(false)

        Overcloud::UndercloudHandle.any_instance
          .expects(:list_stacks).returns([])
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_environments)
          .with('overcloud', @ceph_edit_environments)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_parameters)
          .with('overcloud', @ceph_edit_parameters)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_environments)
          .returns(bad_environments)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_parameters)
          .returns(@ceph_get_parameters)

        body = JSON.parse(post(:sync_openstack, :id => @ceph_openstack_deployment.id).body)
        assert_response 500
        assert_not_empty body['errors']
      end

      test 'sync_openstack should return an error if overcloud parameters are not synchronized when ceph is disabled' do
        Utils::Fusor::OvercloudSSL.any_instance.expects(:gen_certs).returns({'ca' => 'x', 'cert' => 'y', 'key' => 'z'})
        bad_parameters = build_get_plan_parameters(@openstack_deployment)
        bad_parameters['NeutronPublicInterface']['Default'] = 'wrong'

        Overcloud::UndercloudHandle.any_instance
          .expects(:list_stacks).returns([])
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_environments)
          .with('overcloud', @overcloud_edit_environments)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_parameters)
          .with('overcloud', @overcloud_edit_parameters)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_environments)
          .returns(@overcloud_get_environments)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_parameters)
          .returns(bad_parameters)

        body = JSON.parse(post(:sync_openstack, :id => @openstack_deployment.id).body)
        assert_response 500
        assert_not_empty body['errors']
      end


      test 'sync_openstack should return an error if overcloud parameters are not synchronized when ceph is enabled' do
        Utils::Fusor::OvercloudSSL.any_instance.expects(:gen_certs).returns({'ca' => 'x', 'cert' => 'y', 'key' => 'z'})
        bad_parameters = build_get_plan_parameters(@ceph_openstack_deployment)
        bad_parameters['CephExternalMonHost']['Default'] = ''

        Overcloud::UndercloudHandle.any_instance
          .expects(:list_stacks).returns([])
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_environments)
          .with('overcloud', @ceph_edit_environments)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:edit_plan_parameters)
          .with('overcloud', @ceph_edit_parameters)
          .returns(Excon::Response.new)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_environments)
          .returns(@ceph_get_environments)
        Overcloud::UndercloudHandle.any_instance
          .expects(:get_plan_parameters)
          .returns(bad_parameters)

        body = JSON.parse(post(:sync_openstack, :id => @ceph_openstack_deployment.id).body)
        assert_response 500
        assert_not_empty body['errors']
      end
    end
  end
end
