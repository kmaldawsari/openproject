#-- encoding: UTF-8

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

require 'roar/decorator'
require 'roar/json/hal'

module API
  module V3
    module Attachments
      class AttachmentRepresenter < ::API::Decorators::Single
        include API::Decorators::LinkedResource
        include API::Caching::CachedRepresenter

        self_link title_getter: ->(*) { represented.filename }

        associated_resource :author,
                            v3_path: :user,
                            representer: ::API::V3::Users::UserRepresenter

        cached_representer key_parts: %i[author container]

        def self.associated_container_getter
          ->(*) do
            next unless embed_links

            representer = case represented.container
                          when WorkPackage
                            ::API::V3::WorkPackages::WorkPackageRepresenter
                          when WikiPage
                            ::API::V3::WikiPages::WikiPageRepresenter
                          when Message
                            ::API::V3::Posts::PostRepresenter
                          end

            representer.new(represented.container, current_user: current_user)
          end
        end

        def self.associated_container_link
          ->(*) do
            path, title_attribute = case represented.container
                                    when WorkPackage
                                      %i[work_package subject]
                                    when WikiPage
                                      %i[wiki_page title]
                                    when Message
                                      %i[post subject]
                                    end

            ::API::Decorators::LinkObject
              .new(represented,
                   path: path,
                   property_name: :container,
                   title_attribute: title_attribute)
              .to_hash
          end
        end

        associated_resource :container,
                            getter: associated_container_getter,
                            link: associated_container_link

        link :downloadLocation do
          location = if represented.external_storage?
                       represented.remote_url
                     else
                       api_v3_paths.attachment_content(represented.id)
                     end
          {
            href: location
          }
        end

        # TODO: how to check permission for an uncontainered attachable
        # possibly only do it if there is a container as uncontainered attachables will be deleted automatically
        link :delete,
             cache_if: -> { represented.container && represented.deletable?(current_user) } do
          {
            href: api_v3_paths.attachment(represented.id),
            method: :delete
          }
        end

        property :id
        property :file_name,
                 getter: ->(*) { filename }
        property :file_size,
                 getter: ->(*) { filesize }
        property :description,
                 getter: ->(*) {
                   ::API::Decorators::Formattable.new(description, format: 'plain')
                 },
                 render_nil: true
        property :content_type
        property :digest,
                 getter: ->(*) {
                   ::API::Decorators::Digest.new(digest, algorithm: 'md5')
                 },
                 render_nil: true
        property :created_at,
                 exec_context: :decorator,
                 getter: ->(*) { datetime_formatter.format_datetime(represented.created_at) }

        def _type
          'Attachment'
        end
      end
    end
  end
end
