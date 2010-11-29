module IsReputable
  module ReputationChanger
    def self.included(base)
      base.class_eval do
        cattr_accessor :award_classes
      end
      base.extend(ClassMethods)
    end

    module ClassMethods
      def awards_reputation(award_klasses, options = {})
        initialize_changer if self.award_classes.nil?

        award_klasses = [award_klasses] unless award_klasses.kind_of?(Array)
        award_klasses.each do |award_klass|
          if options[:on]
            options[:on] = [options[:on]] unless options[:on].kind_of?(Array)
          else 
            options[:on] = [:update, :create]
          end

          self.award_classes[award_klass] = options

          has_one award_klass.association_name,
            :as         => :subject,
            :class_name => award_klass.name
        end

      end

      private
      def initialize_changer

        #first time this is getting called, so set some things up
        self.award_classes = {}

        has_many :point_awards, :as => :subject, :dependent => :destroy

        include IsReputable::ReputationChanger::InstanceMethods
        after_create :after_create_award_handler
        after_update :after_update_award_handler
        after_destroy :after_destroy_award_handler
      end
    end

    module InstanceMethods
      def after_create_award_handler
        dispense_awards(:create)
      end

      def after_update_award_handler
        dispense_awards(:update)
      end

      def after_destroy_award_handler
        awardables = []
        self.class.award_classes.each do |a, options|
          awardables << award_recipient(options)
        end

        awardables.uniq.each do |a|
          a.recalculate_reputation unless a == self
        end
      end
      
      def dispense_awards(callback)
        self.class.award_classes.each do |a, options|
          if options[:on].include?(callback)
            if(!options[:unique] || !already_awarded?(a, options))
              a.award_to(award_recipient(options), :subject => self)
            end
          end
        end
      end

      def award_recipient(options)
        if options[:to]
          self.send(options[:to])
        else
          self
        end
      end

      def already_awarded?(a, options)
        !self.new_record? && 
          !award_recipient(options).received_point_awards.find(:first,
            :conditions => {
              :subject_id   => self.id,
              :subject_type => ar_descendent_for(self.class).name,
              :type         => a.name  
          }).nil?
      end

      def ar_descendent_for(klass)
        if klass.superclass == ActiveRecord::Base
          klass
        elsif klass.superclass.nil?
          raise "not a child of ActiveRecord::Base"
        else
          ar_descendent_for(klass.superclass)
        end
      end

    end
  end
end
