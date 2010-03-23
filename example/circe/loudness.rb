module Project
  module Plugin
    module Loudness
      module Speaker
        def say(what)
          super what.upcase
        end
      end
    end
  end
end
