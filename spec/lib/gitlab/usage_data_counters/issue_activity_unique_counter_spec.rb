# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UsageDataCounters::IssueActivityUniqueCounter, :clean_gitlab_redis_shared_state do
  let(:user1) { build(:user, id: 1) }
  let(:user2) { build(:user, id: 2) }
  let(:user3) { build(:user, id: 3) }
  let(:time) { Time.zone.now }

  shared_examples 'tracks and counts action' do
    before do
      stub_application_setting(usage_ping_enabled: true)
    end

    def count_unique(date_from:, date_to:)
      Gitlab::UsageDataCounters::HLLRedisCounter.unique_events(event_names: action, start_date: date_from, end_date: date_to)
    end

    specify do
      aggregate_failures do
        expect(track_action(author: user1)).to be_truthy
        expect(track_action(author: user1)).to be_truthy
        expect(track_action(author: user2)).to be_truthy
        expect(track_action(author: user3, time: time - 3.days)).to be_truthy

        expect(count_unique(date_from: time, date_to: time)).to eq(2)
        expect(count_unique(date_from: time - 5.days, date_to: 1.day.since(time))).to eq(3)
      end
    end

    it 'does not track edit actions if author is not present' do
      expect(track_action(author: nil)).to be_nil
    end

    context 'when feature flag track_issue_activity_actions is disabled' do
      it 'does not track edit actions' do
        stub_feature_flags(track_issue_activity_actions: false)

        expect(track_action(author: user1)).to be_nil
      end
    end
  end

  context 'for Issue title edit actions' do
    it_behaves_like 'tracks and counts action' do
      let(:action) { described_class::ISSUE_TITLE_CHANGED }

      def track_action(params)
        described_class.track_issue_title_changed_action(params)
      end
    end
  end

  context 'for Issue description edit actions' do
    it_behaves_like 'tracks and counts action' do
      let(:action) { described_class::ISSUE_DESCRIPTION_CHANGED }

      def track_action(params)
        described_class.track_issue_description_changed_action(params)
      end
    end
  end

  context 'for Issue assignee edit actions' do
    it_behaves_like 'tracks and counts action' do
      let(:action) { described_class::ISSUE_ASSIGNEE_CHANGED }

      def track_action(params)
        described_class.track_issue_assignee_changed_action(params)
      end
    end
  end

  context 'for Issue make confidential actions' do
    it_behaves_like 'tracks and counts action' do
      let(:action) { described_class::ISSUE_MADE_CONFIDENTIAL }

      def track_action(params)
        described_class.track_issue_made_confidential_action(params)
      end
    end
  end

  context 'for Issue make visible actions' do
    it_behaves_like 'tracks and counts action' do
      let(:action) { described_class::ISSUE_MADE_VISIBLE }

      def track_action(params)
        described_class.track_issue_made_visible_action(params)
      end
    end
  end

  it 'can return the count of actions per user deduplicated', :aggregate_failures do
    described_class.track_issue_title_changed_action(author: user1)
    described_class.track_issue_description_changed_action(author: user1)
    described_class.track_issue_assignee_changed_action(author: user1)
    described_class.track_issue_title_changed_action(author: user2, time: time - 2.days)
    described_class.track_issue_title_changed_action(author: user3, time: time - 3.days)
    described_class.track_issue_description_changed_action(author: user3, time: time - 3.days)
    described_class.track_issue_assignee_changed_action(author: user3, time: time - 3.days)

    events = Gitlab::UsageDataCounters::HLLRedisCounter.events_for_category(described_class::ISSUE_CATEGORY)
    today_count = Gitlab::UsageDataCounters::HLLRedisCounter.unique_events(event_names: events, start_date: time, end_date: time)
    week_count = Gitlab::UsageDataCounters::HLLRedisCounter.unique_events(event_names: events, start_date: time - 5.days, end_date: 1.day.since(time))

    expect(today_count).to eq(1)
    expect(week_count).to eq(3)
  end
end
