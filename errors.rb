# frozen_string_literal: true

module EasyMonad
  class Errors < Hash
    def add(key, value)
      self[key] ||= value
    end

    def to_a
      map { |key, val| "#{key}: #{val}" }
    end

    def to_s
      to_a.join(', ')
    end

    def only_messages
      values.flatten.map { _1.delete(':') }
    end
  end
end
