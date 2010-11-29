module IsReputable
  def self.included(base)
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)
  end

  module ClassMethods
    def is_reputable
      has_many :received_point_awards, 
        :class_name => "PointAward",
        :as         => :awardable
    end
  end

  module InstanceMethods
    def recalculate_reputation
      self.reputation_score = self.received_point_awards.sum("points")
      self.save! if self.changes.keys.include?("reputation_score")
    end
  end
end

