module Project
  module Spells
    module Loudness
      module Speaker
        module InstanceMethods
          def say(what)
            super what.upcase
          end
        end
      end
    end
  end
end
