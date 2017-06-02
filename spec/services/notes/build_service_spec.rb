require 'spec_helper'

describe Notes::BuildService, services: true do
  let(:note) { create(:discussion_note_on_issue) }
  let(:project) { note.project }
  let(:author) { note.author }

  describe '#execute' do
    context 'when in_reply_to_discussion_id is specified' do
      context 'when a discussion note with that original discussion ID exists' do
        it 'sets the note up to be in reply to that note' do
          new_note = described_class.new(project, author, note: 'Test', in_reply_to_discussion_id: note.discussion_id).execute
          expect(new_note).to be_valid
          expect(new_note).to be_a(DiscussionNote)
          expect(new_note.discussion_id).to eq(note.discussion_id)
          expect(new_note.in_reply_to?(note)).to be_truthy
        end
      end

      context 'when a discussion note with that discussion ID exists' do
        it 'sets the note up to be in reply to that note' do
          new_note = described_class.new(project, author, note: 'Test', in_reply_to_discussion_id: note.discussion_id).execute
          expect(new_note).to be_valid
          expect(new_note).to be_a(DiscussionNote)
          expect(new_note.discussion_id).to eq(note.discussion_id)
          expect(new_note.in_reply_to?(note)).to be_truthy
        end
      end

      context 'when a regular note with that discussion ID exists' do
        let(:note) { create(:note_on_issue) }

        context 'when new_discussion is set' do
          it 'sets the note up to be a reply to that note' do
            new_note = described_class.new(project, author, note: 'Test', in_reply_to_discussion_id: note.discussion_id, new_discussion: true).execute
            expect(new_note).to be_valid
            expect(new_note).to be_a(DiscussionNote)
            expect(new_note.discussion_id).to eq(note.discussion_id)
            expect(new_note.in_reply_to?(note)).to be_truthy
          end

          it 'transforms the original note into a discussion note when saved' do
            new_note = described_class.new(project, author, note: 'Test', in_reply_to_discussion_id: note.discussion_id, new_discussion: true).execute

            new_note.save

            # We can't use reload because we want a new instance
            original_note = Note.find(note.id)
            expect(original_note).to be_a(DiscussionNote)
            expect(original_note.discussion_id).to eq(new_note.discussion_id)
          end
        end

        context 'when new_discussion is not set' do
          it 'sets the note up to be a regular comment on the noteable' do
            new_note = described_class.new(project, author, note: 'Test', in_reply_to_discussion_id: note.discussion_id).execute
            expect(new_note).to be_valid
            expect(new_note.discussion_id).not_to eq(note.discussion_id)
            expect(new_note.in_reply_to?(note)).to be_truthy
          end
        end
      end

      context 'when no note with that discussion ID exists' do
        it 'sets an error' do
          new_note = described_class.new(project, author, note: 'Test', in_reply_to_discussion_id: 'foo').execute
          expect(new_note.errors[:base]).to include('Discussion to reply to cannot be found')
        end
      end

      context 'personal snippet note' do
        def reply(note, user = nil)
          user ||= create(:user)

          described_class.new(nil,
                              user,
                              note: 'Test',
                              in_reply_to_discussion_id: note.discussion_id).execute
        end

        let(:snippet_author) { create(:user) }

        context 'when a snippet is public' do
          it 'creates a reply note' do
            snippet = create(:personal_snippet, :public)
            note = create(:discussion_note_on_personal_snippet, noteable: snippet)

            new_note = reply(note)

            expect(new_note).to be_valid
            expect(new_note.in_reply_to?(note)).to be_truthy
          end
        end

        context 'when a snippet is private' do
          let(:snippet) { create(:personal_snippet, :private, author: snippet_author) }
          let(:note) { create(:discussion_note_on_personal_snippet, noteable: snippet) }

          it 'creates a reply note when the author replies' do
            new_note = reply(note, snippet_author)

            expect(new_note).to be_valid
            expect(new_note.in_reply_to?(note)).to be_truthy
          end

          it 'sets an error when another user replies' do
            new_note = reply(note)

            expect(new_note.errors[:base]).to include('Discussion to reply to cannot be found')
          end
        end

        context 'when a snippet is internal' do
          let(:snippet) { create(:personal_snippet, :internal, author: snippet_author) }
          let(:note) { create(:discussion_note_on_personal_snippet, noteable: snippet) }

          it 'creates a reply note when the author replies' do
            new_note = reply(note, snippet_author)

            expect(new_note).to be_valid
            expect(new_note.in_reply_to?(note)).to be_truthy
          end

          it 'creates a reply note when a regular user replies' do
            new_note = reply(note)

            expect(new_note).to be_valid
            expect(new_note.in_reply_to?(note)).to be_truthy
          end

          it 'sets an error when an external user replies' do
            new_note = reply(note, create(:user, :external))

            expect(new_note.errors[:base]).to include('Discussion to reply to cannot be found')
          end
        end
      end
    end

    it 'builds a note without saving it' do
      new_note = described_class.new(project,
                                    author,
                                    noteable_type: note.noteable_type,
                                    noteable_id: note.noteable_id,
                                    note: 'Test').execute
      expect(new_note).to be_valid
      expect(new_note).not_to be_persisted
    end
  end
end
