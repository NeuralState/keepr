module Keepr::ActiveRecordExtension
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def has_one_keepr_account
      has_one :keepr_account, :class_name => 'Keepr::Account', :as => :accountable
      has_many :keepr_postings, :class_name => 'Keepr::Posting', :through => :keepr_account
    end

    def has_many_keepr_accounts
      has_many :keepr_accounts, :class_name => 'Keepr::Account', :as => :accountable
      has_many :keepr_postings, :class_name => 'Keepr::Posting', :through => :keepr_accounts
    end

    def is_keepr_accountable
      has_many :keepr_journals, :class_name => 'Keepr::Journal', :as => :accountable

      class_eval <<-EOT
        def keepr_booked?
          keepr_journals.exists?
        end

        scope :keepr_unbooked, -> {
                                    joins('LEFT JOIN keepr_journals ON keepr_journals.accountable_id = #{table_name}.id AND keepr_journals.accountable_type="#{base_class.name}"').
                                    where('keepr_journals.id' => nil)
                                  }
        scope :keepr_booked,   -> { joins(:keepr_journals) }
      EOT
    end
  end
end
