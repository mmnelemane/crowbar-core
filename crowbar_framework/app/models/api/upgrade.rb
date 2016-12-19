#
# Copyright 2016, SUSE LINUX GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "open3"

module Api
  class Upgrade < Tableless
    def status
      {
        crowbar: crowbar_upgrade_status,
        checks: check
      }
    end

    def check
      {
        sanity_checks: sanity_checks,
        maintenance_updates_missing: maintenance_updates_missing?,
        clusters_healthy: clusters_healthy?,
        compute_resources_available: compute_resources_available?,
        ceph_healthy: ceph_healthy?
      }
    end

    def repocheck
      response = {}
      addons = Api::Crowbar.new.addons
      addons.push("os", "openstack").each do |addon|
        response.merge!(Api::Node.new.repocheck(addon: addon))
      end
      response
    end

    def target_platform(options = {})
      platform_exception = options.fetch(:platform_exception, nil)

      case Api::Crowbar.new.version
      when "4.0"
        if platform_exception == :ceph
          ::Crowbar::Product.ses_platform
        else
          NodeObject.admin_node.target_platform
        end
      end
    end

    # Shutdown non-essential services on all nodes.
    def services
      status = :ok
      msg = ""
      begin
        # prepare the scripts for various actions necessary for the upgrade
        service_object = CrowbarService.new(Rails.logger)
        service_object.prepare_nodes_for_os_upgrade
      rescue => e
        msg = e.message
        Rails.logger.error msg
        status = :unprocessable_entity
        return [status, msg]
      end

      # Initiate the services shutdown by calling scripts on all nodes.
      # For each cluster, it is enough to initiate the shutdown from one node (e.g. founder)
      NodeObject.find("state:crowbar_upgrade AND pacemaker_founder:true").each do |node|
        node.ssh_cmd("/usr/sbin/crowbar-shutdown-services-before-upgrade.sh")
      end
      # Shutdown the services for non clustered nodes
      NodeObject.find("state:crowbar_upgrade AND NOT run_list_map:pacemaker-cluster-member").
        each do |node|
        node.ssh_cmd("/usr/sbin/crowbar-shutdown-services-before-upgrade.sh")
      end
      [status, msg]
    end

    protected

    def crowbar_upgrade_status
      Api::Crowbar.new.upgrade
    end

    def sanity_checks
      ::Crowbar::Sanity.sane? || ::Crowbar::Sanity.check
    end

    def maintenance_updates_missing?
      Api::Crowbar.new.maintenance_updates_missing?
    end

    def ceph_healthy?
      Api::Crowbar.new.ceph_healthy?
    end

    def clusters_healthy?
      # FIXME: to be implemented
      true
    end

    def compute_resources_available?
      Api::Crowbar.new.compute_resources_available?
    end
  end
end
