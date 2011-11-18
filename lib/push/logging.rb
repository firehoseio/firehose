# Make logging easier in various classes
module Push::Logging
private
  def logger
    Push.logger
  end

  def log(message,level=:info)
    Push.logger.send(level, "#{self.class.name}: #{message}")
  end
end