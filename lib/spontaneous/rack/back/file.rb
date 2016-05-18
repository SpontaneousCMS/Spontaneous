module Spontaneous::Rack::Back
  module File
    class Simple < Base
      put '/:id/?:box_id?' do
        content_for_request(true) do |content, box|
          target = box || content
          file = params[:file]
          field = target.fields.sid(params['field'])
          forbidden! unless target.field_writable?(user, field.name)
          # version = params[:version].to_i
          # if version == field.version
          Spontaneous::Field.set_asynchronously(site, field, file, user)
          json(field.export(user))
          # else
          #   errors = [[field.schema_id.to_s, [field.version, field.conflicted_value]]]
          #   [409, json(Hash[errors])]
          # end
        end
      end

      post '/:id/:box_id' do
        content_for_request(true) do |content, box|
          file = params['file']
          type = box.type_for_mime_type(file[:type])
          if type
            forbidden! unless box.writable?(user, type)
            position = 0
            instance = type.new
            box.insert(position, instance)
            field = instance.field_for_mime_type(file[:type])
            Spontaneous::Field.set_asynchronously(site, field, file, user)
            content.save
            json({
              :position => position,
              :entry => instance.entry.reload.export(user)
            })
          end
        end
      end
    end

    class Sharded < Base
      get '/:sha1' do
        shard = Spontaneous.shard_path(params[:sha1])
        if ::File.file?(shard)
          # touch the shard file so that clean up routines can delete unmodified files
          # without affecting any uploads in progresss
          FileUtils.touch(shard)
          200
        else
          404
        end
      end

      post '/:sha1' do
        file = params[:file]
        uploaded_hash = Spontaneous::Media.digest(file[:tempfile].path)
        if uploaded_hash == params[:sha1] # rand(10000) % 2 == 0 # use to test shard re-uploading
          shard_path = Spontaneous.shard_path(params[:sha1])
          FileUtils.mv(file[:tempfile].path, shard_path)
          200
        else
          ::Rack::Utils.status_code(:conflict) #409
        end
      end

      put '/:id/?:box_id?' do
        content_for_request(true) do |content, box|
          target = box || content
          replace_with_shard(target, content.id)
        end
      end

      # TODO: remove duplication here
      post '/:id/:box_id' do
        content_for_request(true) do |content, box|
          type = box.type_for_mime_type(params[:mime_type])
          if type
            forbidden! unless box.writable?(user, type)
            position = 0
            instance = type.new
            box.insert(position, instance)
            field = instance.field_for_mime_type(params[:mime_type])
            Spontaneous::Media.combine_shards(params[:shards]) do |combined|
              tempfile = { :filename => params[:filename], :tempfile => combined }
              Spontaneous::Field.set_asynchronously(site, field, tempfile, user)
              content.save
            end
            json({
              :position => position,
              :entry => instance.entry.reload.export(user)
            })
          end
        end
      end

      def replace_with_shard(target, target_id)
        field = target.fields.sid(params[:field])
        forbidden! unless target.field_writable?(user, field.name)
        # version = params[:version].to_i
        # if version == field.version
        Spontaneous::Media.combine_shards(params[:shards]) do |combined|
          tempfile = { :filename => params[:filename], :tempfile => combined }
          Spontaneous::Field.set_asynchronously(site, field, tempfile, user)
        end
        json(field.export(user))
      end
    end
  end
end
