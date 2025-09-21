# 基础模型类
class BaseModel < Sequel::Model
  plugin :timestamps, update_on_create: true
  plugin :validation_helpers

  def self.paginate(page: 1, per_page: 20)
    offset = (page.to_i - 1) * per_page.to_i
    limit(per_page.to_i, offset)
  end

  def to_hash
    values.merge(
      created_at_formatted: created_at&.strftime('%Y-%m-%d %H:%M:%S'),
      updated_at_formatted: updated_at&.strftime('%Y-%m-%d %H:%M:%S')
    )
  end
end