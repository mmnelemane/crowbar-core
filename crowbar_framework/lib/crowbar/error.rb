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

module Crowbar
  module Error
    autoload :UpgradeError,
      File.expand_path("../error/upgrade", __FILE__)

    autoload :UpgradeCancelError,
      File.expand_path("../error/upgrade", __FILE__)

    autoload :UpgradeNotEnoughDiskSpaceError,
      File.expand_path("../error/upgrade", __FILE__)

    autoload :UpgradeFreeDiskSpaceError,
      File.expand_path("../error/upgrade", __FILE__)

    autoload :UpgradeDatabaseDumpError,
      File.expand_path("../error/upgrade", __FILE__)

    autoload :UpgradeDatabaseSizeError,
      File.expand_path("../error/upgrade", __FILE__)
  end
end
