#associations for nested classes is broken for the has_many &block case.
# bug fix has been open for 2 years:
# http://dev.rubyonrails.org/ticket/6450
# but not applied.
#
# REASON: I want to be able to use acts_as_versioned and acts_as_paranoid, which both use the 
#         has_many &block construct.
#         Freemium uses nested model names, for namespacing purposes, so this construct fails 
#         without these fixes
#
# tested with Rails 2.0.2
module ActiveRecord
  module Associations # :nodoc:
    module ClassMethods
    
      private
      
        def create_extension_modules(association_id, block_extension, extensions)
          extension_module_name = "#{self.to_s.demodulize}#{association_id.to_s.camelize}AssociationExtension" 
          #this is the part that is broken... need to demodulize the class.
          # cannot use Freemium::SubscriptionVersionAssociationExtension.  Needs to be
          #            FreemiumSubscriptionVersionAssociationExtension
          # extension_module_name = "#{self.to_s}#{association_id.to_s.camelize}AssociationExtension"
          silence_warnings do
            Object.const_set(extension_module_name, Module.new(&block_extension))
          end
          Array(extensions).push(extension_module_name.constantize)
        end
    end
  end
end