BEGIN;

CREATE TABLE IF NOT EXISTS wish_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wish_id UUID NOT NULL REFERENCES wishes (id) ON DELETE CASCADE,
  author_user_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  parent_reply_id UUID REFERENCES wish_replies (id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT wish_replies_content_not_blank_chk CHECK (btrim(content) <> '')
);

CREATE INDEX IF NOT EXISTS idx_wish_replies_wish_created_at_btree
  ON wish_replies (wish_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_wish_replies_parent_reply_btree
  ON wish_replies (parent_reply_id);

COMMENT ON TABLE wish_replies IS
  'Public text replies written against a wish, with optional one-level or recursive threading via parent_reply_id.';

COMMENT ON COLUMN wish_replies.parent_reply_id IS
  'Optional self-reference used to support direct replies to an existing wish reply.';

COMMIT;
