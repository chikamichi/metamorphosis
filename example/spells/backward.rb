module Project
  module Spells
    module Backward
      #def self.unpack
        ## ne sert à rien dans cet exemple, mais pourrait être utile
        ## dans certains cas (send :include, ClassMethods par exemple)
        #puts "Unpacking #{self}"
        #puts
      #end

      # TODO
      # peut-être imposer la convention que les classes de Base redéfinies ici
      # sont à placer dans un module du même nom (Base, donc) ?
      # Auquel cas, modifier en conséquence le hooking automatique dans Pluginable#activate etc.
      # module Base
      module Speaker
        module InstanceMethods
          def say what
            super what.reverse
          end
        end
      end
      #end

      # TODO
      # Voilà la convention que je propose :
      # module Base::Plugin::Backward...
      # module Base
      #   module Speaker
      #     def self.unpack
      #       # this is configuration over convention
      #     end
      #
      #     # this is convention
      #     module InstanceMethods
      #       def say what
      #         super what.reverse
      #       end
      #     end
      #
      #     module ClassMethods
      #       def foobar
      #       end
      #     end
      #   end
      # end
      #
      # Dans Pluginable.activate, on vérifie s'il existe la méthode unpack :
      # - si oui, alors l'exécuter et c'est tout ;
      # - si non, alors obtenir la liste des modules déclarés par le plugin, puis pour chacun de
      #   ceux qui sont dans @redefinable :
      #   - faire un extend ClassMethods sur le module ou la classe correspondante du receiver ;
      #   - faire un extend Pluginable::PlugInit sur le module ou la classe correspondante du receiver,
      #     de façon à faire le extend InstanceMethods sur les instances, le moment venu.
      #
      # De cette façon, on n'a rien à déclarer du tout, c'est automagical à partir du moment où
      # on suit la convention (et on peut s'en passer si on veut, avec unpack, peut-être à renommer
      # custom_unpack du coup).
    end
  end
end
