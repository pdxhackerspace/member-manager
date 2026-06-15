# Converts user-facing strings to ASCII for access controller scripts and env vars.
# Non-ASCII characters are transliterated when possible; anything else is dropped.
class AccessControllerTextNormalizer
  def self.call(value)
    new(value).call
  end

  def initialize(value)
    @value = value
  end

  def call
    return nil if @value.nil?

    ActiveSupport::Inflector.transliterate(@value.to_s, '').strip
  end
end
