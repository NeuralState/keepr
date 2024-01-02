# frozen_string_literal: true

require 'spec_helper'

describe Keepr::Group do
  describe 'validations' do
    it 'should allow is_result for liability' do
      group = Keepr::Group.new(is_result: true, target: :liability, name: 'foo')
      expect(group).to be_valid
    end

    %i[asset profit_and_loss].each do |target|
      it "should not allow is_result for #{target}" do
        group = Keepr::Group.new(is_result: true, target: target, name: 'foo')
        expect(group).not_to be_valid
        expect(group.errors.added?(:base, :liability_needed_for_result)).to eq(true)
      end
    end
  end

  describe :get_from_parent do
    it 'should preset parent' do
      root = FactoryBot.create :group, target: :asset
      child = root.children.create! name: 'Bar'

      expect(child.target).to eq('asset')
    end
  end

  describe :keepr_accounts do
    it 'should not destroy if there are accounts' do
      group = FactoryBot.create :group
      FactoryBot.create :account, number: 1000, keepr_group: group

      expect { group.destroy }.to_not change(Keepr::Group, :count)
      expect(group.destroy).to eq(false)
      expect(group.reload).to eq(group)
    end

    it 'should destroy if there are no accounts' do
      group = FactoryBot.create :group

      expect { group.destroy }.to change { Keepr::Group.count }.by(-1)
    end
  end

  describe :keepr_postings do
    # Simple asset group hierarchy
    let(:group_1)     { FactoryBot.create :group, target: :asset }
    let(:group_1_1)   { FactoryBot.create :group, target: :asset, parent: group_1 }
    let(:group_1_1_1) { FactoryBot.create :group, target: :asset, parent: group_1_1 }

    # Group for P&L accounts
    let(:group_2)     { FactoryBot.create :group, target: :profit_and_loss }

    # Group for balance result
    let(:group_result) { FactoryBot.create :group, target: :liability, is_result: true }

    # Accounts
    let(:account_1a)  { FactoryBot.create :account, number: '0001', keepr_group: group_1_1_1 }
    let(:account_1b)  { FactoryBot.create :account, number: '0011', keepr_group: group_1_1_1 }
    let(:account_1c)  { FactoryBot.create :account, number: '0111', keepr_group: group_1_1_1 }

    let(:account_2)   { FactoryBot.create :account, number: '8400', keepr_group: group_2, kind: :equity }

    # Journals
    let!(:journal1)   do
      Keepr::Journal.create! keepr_postings_attributes: [
        { keepr_account: account_1a, amount: 100.99, side: 'debit' },
        { keepr_account: account_2, amount: 100.99, side: 'credit' }
      ]
    end
    let!(:journal2) do
      Keepr::Journal.create! keepr_postings_attributes: [
        { keepr_account: account_1b, amount: 100.99, side: 'debit' },
        { keepr_account: account_2, amount: 100.99, side: 'credit' }
      ]
    end
    let!(:journal3) do
      Keepr::Journal.create! keepr_postings_attributes: [
        { keepr_account: account_1c, amount: 100.99, side: 'debit' },
        { keepr_account: account_2, amount: 100.99, side: 'credit' }
      ]
    end

    context 'for normal groups' do
      it 'should return postings of all accounts within the group' do
        postings1 = [journal1.debit_postings.first, journal2.debit_postings.first, journal3.debit_postings.first]
        expect(group_1.keepr_postings).to eq(postings1)
        expect(group_1_1.keepr_postings).to eq(postings1)
        expect(group_1_1_1.keepr_postings).to eq(postings1)

        postings2 = [journal1.credit_postings.first, journal2.credit_postings.first, journal3.credit_postings.first]
        expect(group_2.keepr_postings).to eq(postings2)
      end
    end

    context 'for result group' do
      it 'should return postings for P&L accounts' do
        result_postings = [journal1.credit_postings.first,
                           journal2.credit_postings.first,
                           journal3.credit_postings.first]

        expect(group_result.keepr_postings).to eq(result_postings)
      end
    end
  end
end
