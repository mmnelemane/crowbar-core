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

# the root class
class IntelRSD < ActiveResource::Base
  attr_accessor :host, :port, :protocol

  def initialize
    @managers = Managers.new
    @systems = Systems.new
    @chassis = Chassis.new
    @redfish_client = RedfishHelper::RedfishClient.new(host, port, protocol)
  end

  def self.get_version
  end

  def self.get_uuid
  end

  def self.get_managers
    @managers
  end

  def self.get_systems
    @systems
  end

  def self.get_chassis
    @chassis
  end
end

# Managers
class Managers

  def get_links
  end

  def get_managed_systems
  end

  def get_managed_services
  end

  def get_managed_switches
  end

  def get_managed_interfaces
  end
end

# Systems 
class Systems
  def get_links
  end

  def get_systemid_list
  end

  def get_system_processors
  end

  def get_system_memory
  end
  
  def get_system_info
  end

  def get_system_interfaces
  end

  def get_system_chassis
  end

  def reset_system
  end
end

#Chassis
class Chassis
  def get_links
  end

  def get_chassis_systems
  end
end


#Services
class Services
end

class Switches
  def get_switch_ports
  end

  def get_switch_vlans
  end
end

class Interfaces
  def get_interface_protocols
  end

  def get_interface_managers
  end

  def get_interface_systems
  end
end


