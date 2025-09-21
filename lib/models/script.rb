# 脚本模型
class Script < BaseModel(:scripts)
  one_to_many :script_executions

  def validate
    super
    validates_presence [:name, :script_type, :file_path]
    validates_unique :name
    validates_includes ScriptManager::SCRIPT_TYPES, :script_type
  end

  def content
    File.exist?(file_path) ? File.read(file_path) : ''
  end

  def file_size
    File.exist?(file_path) ? File.size(file_path) : 0
  end

  def last_execution
    script_executions_dataset.order(Sequel.desc(:execution_time)).first
  end

  def execution_count
    script_executions_dataset.count
  end

  def success_rate
    total = execution_count
    return 0 if total == 0
    
    success_count = script_executions_dataset.where(success: true).count
    (success_count.to_f / total * 100).round(2)
  end

  def to_hash
    super.merge(
      file_size: file_size,
      execution_count: execution_count,
      success_rate: success_rate,
      last_execution: last_execution&.execution_time
    )
  end
end

# 脚本执行记录模型
class ScriptExecution < BaseModel(:script_executions)
  many_to_one :script
  many_to_one :resource

  def validate
    super
    validates_presence [:script_id, :command]
  end

  def duration
    return nil unless start_time && end_time
    end_time - start_time
  end

  def to_hash
    super.merge(
      script_name: script&.name,
      resource_name: resource&.name,
      duration: duration
    )
  end
end