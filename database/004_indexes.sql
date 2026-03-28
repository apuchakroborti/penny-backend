BEGIN;

CREATE INDEX IF NOT EXISTS idx_wishes_embedding_ivfflat
  ON wishes
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100)
  WHERE embedding IS NOT NULL
    AND visibility = 'public'
    AND is_moderated = FALSE;

CREATE INDEX IF NOT EXISTS idx_wishes_user_id_btree
  ON wishes (user_id);

CREATE INDEX IF NOT EXISTS idx_wishes_emotion_label_btree
  ON wishes (emotion_label);

CREATE INDEX IF NOT EXISTS idx_wishes_created_at_btree
  ON wishes (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_interactions_actor_type_btree
  ON interactions (actor_user_id, type);

CREATE INDEX IF NOT EXISTS idx_matches_user_a_user_b_btree
  ON matches (user_id_a, user_id_b);

CREATE INDEX IF NOT EXISTS idx_matches_user_b_user_a_btree
  ON matches (user_id_b, user_id_a);

CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_active_user_pair_unique
  ON matches (LEAST(user_id_a, user_id_b), GREATEST(user_id_a, user_id_b))
  WHERE match_status IN ('pending', 'opened');

CREATE INDEX IF NOT EXISTS idx_messages_conversation_sent_at_btree
  ON messages (conversation_id, sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read_btree
  ON notifications (user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_wish_tags_tag_gin
  ON wish_tags
  USING gin (tag gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_wishes_content_trgm
  ON wishes
  USING gin (content gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_wishes_visibility_content_gin
  ON wishes
  USING gin (visibility, content gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_matches_shared_themes_gin
  ON matches
  USING gin (shared_themes);

COMMIT;
