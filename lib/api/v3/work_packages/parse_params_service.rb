#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2018 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

module API
  module V3
    module WorkPackages
      class ParseParamsService
        def initialize(user)
          @current_user = user
        end

        def call(request_body, project: nil, type: nil)
          return {} unless request_body

          parse_attributes(request_body, project, type)
        end

        private

        attr_accessor :current_user

        def parse_attributes(request_body, project, type)
          # we need to merge the JSON two times:
          # In Pass 1 the representer only has custom fields for the current WP type/project
          # After Pass 1 the correct type/project information is merged into the WP
          # In Pass 2 the representer is created with the new type/project info and will be able
          # to also parse custom fields successfully
          # TODO: create a representer class with all available custom fields, keep it between requests
          # and use it for parsing
          initial_struct = ParsingStruct.new(project, type, {})

          hash = parse_attributes_with_representer(request_body, initial_struct)

          updated_struct = ParsingStruct.new(project, type, hash)

          if initial_struct.available_custom_fields != updated_struct.available_custom_fields
            hash = parse_attributes_with_representer(request_body, updated_struct)
          end

          hash
        end

        def parse_attributes_with_representer(hash, struct)
          klass = ::API::V3::WorkPackages::WorkPackagePayloadRepresenter.create_class(struct)

          klass
            .new(struct, current_user: current_user)
            .from_hash(Hash(hash))
            .to_h
            .reverse_merge(lock_version: nil)
        end

        class ParsingStruct < OpenStruct
          def initialize(project, type, hash)
            super()

            send(:available_custom_fields=, custom_fields_for(project, type, hash))
            send(:'milestone?=', type.is_milestone?)
          end

          def custom_fields_for(project, type, hash)
            project = hash[:project_id] ? Project.find_by(id: hash[:project_id]) : project
            type = hash[:type_id] ? Type.find_by(id: hash[:type_id]) : type

            ::WorkPackage::AvailableCustomFields.for(project, type)
          end

          def to_h
            super
              .except(:available_custom_fields,
                      :milestone?)
          end
        end
      end
    end
  end
end
