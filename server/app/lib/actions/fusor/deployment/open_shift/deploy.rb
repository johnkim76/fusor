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
      module OpenShift
        class Deploy < Actions::Fusor::FusorBaseAction
          def humanized_name
            _("Deploy OpenShift Management Engine")
          end

          def plan(deployment)
            super(deployment)
            ::Fusor.log.info "Planning OpenShift Deployment"

            sequence do
#              if deployment.ose_install_loc == 'RHEV'
                
                # this arbitrary image file name will be used for creat the image path, 
                # also used for uploading the image via engine uploader
                image_file_name = "rhel-guest-image-7"

                plan_action(::Actions::Fusor::Deployment::OpenShift::InstallImage,
                            deployment, image_file_name)

                upload_action = plan_action(::Actions::Fusor::Deployment::Rhev::UploadImage,
                            deployment, image_file_name, "ose")

                plan_action(::Actions::Fusor::Deployment::Rhev::ImportTemplate,
                            deployment, upload_action.output[:template_name])

                plan_action(::Actions::Fusor::Deployment::Rhev::OseLaunch, deployment)
#              end
            end
          end
        end
      end
    end
  end
end
