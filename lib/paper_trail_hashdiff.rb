# frozen_string_literal: true

# Allows storing only incremental changes in the object_changes column
# Uses HashDiff (https://github.com/liufengyun/hashdiff)
class PaperTrailHashDiff
  attr_reader :only_objects

  def initialize(only_objects: false)
    @only_objects = only_objects
  end

  def diff(changes)
    diff_changes = {}
    changes.each do |field, value_changes|
      old_value = convert_to_hash(value_changes[0])
      new_value = convert_to_hash(value_changes[1])

      diff_changes[field] =
        if !only_objects || (
          old_value && new_value &&
          (old_value.is_a?(Hash) || new_value.is_a?(Array))
        )
          Hashdiff.diff(old_value, new_value, array_path: true, use_lcs: false)
        else
          value_changes
        end
    end
    diff_changes
  end

  def where_object_changes(version_model_class, attributes)
    scope = version_model_class
    attributes.each do |k, v|
      scope = scope.where('(((object_changes -> ?)::jsonb ->> 0)::jsonb @> ?)', k.to_s, v.to_s)
    end
    scope
  end

  def load_changeset(version)
    HashWithIndifferentAccess.new(version.object_changes_deserialized)
  end

  private

  def convert_to_hash(value)
    return value unless defined?(StoreModel::Model) && value.is_a?(StoreModel::Model)

    value.as_json
  end
end
