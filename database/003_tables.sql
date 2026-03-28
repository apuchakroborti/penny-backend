BEGIN;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  anonymous_name TEXT NOT NULL,
  email_hash BYTEA NOT NULL,
  password_hash TEXT NOT NULL,
  intent user_intent_enum NOT NULL,
  current_mood TEXT,
  is_premium BOOLEAN NOT NULL DEFAULT FALSE,
  premium_expires_at TIMESTAMPTZ,
  is_banned BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT users_anonymous_name_key UNIQUE (anonymous_name),
  CONSTRAINT users_email_hash_key UNIQUE (email_hash),
  CONSTRAINT users_anonymous_name_format_chk
    CHECK (anonymous_name ~ '^[A-Za-z]+_[A-Za-z0-9]{2,12}$'),
  CONSTRAINT users_email_hash_len_chk
    CHECK (octet_length(email_hash) = 32),
  CONSTRAINT users_password_hash_not_blank_chk
    CHECK (btrim(password_hash) <> ''),
  CONSTRAINT users_current_mood_not_blank_chk
    CHECK (current_mood IS NULL OR btrim(current_mood) <> ''),
  CONSTRAINT users_premium_expiry_consistency_chk
    CHECK (premium_expires_at IS NULL OR premium_expires_at >= created_at)
);

COMMENT ON TABLE users IS
  'Core account table for Wishing Well. Stores only anonymized identity fields and hashed email lookup values.';
COMMENT ON COLUMN users.anonymous_name IS
  'Public-safe identity string such as Echo_47. Generated automatically when omitted.';
COMMENT ON COLUMN users.email_hash IS
  'SHA-256 hash of the normalized email address. Raw email addresses are never stored.';
COMMENT ON COLUMN users.password_hash IS
  'Application-managed password hash (bcrypt, Argon2, or equivalent).';
COMMENT ON COLUMN users.premium_expires_at IS
  'Optional entitlement horizon used together with subscriptions for premium gating.';

CREATE TABLE IF NOT EXISTS user_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT user_tags_user_id_tag_key UNIQUE (user_id, tag),
  CONSTRAINT user_tags_tag_not_blank_chk CHECK (btrim(tag) <> ''),
  CONSTRAINT user_tags_tag_normalized_chk CHECK (tag = lower(tag))
);

COMMENT ON TABLE user_tags IS
  'Normalized, user-selected interests and emotional context tags used for discovery and personalization.';

CREATE TABLE IF NOT EXISTS wishes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  content TEXT NOT NULL,
  ai_refined_content TEXT,
  used_ai_refinement BOOLEAN NOT NULL DEFAULT FALSE,
  emotion_label wish_emotion_enum NOT NULL,
  emotion_score DOUBLE PRECISION NOT NULL,
  embedding VECTOR(1536),
  visibility wish_visibility_enum NOT NULL DEFAULT 'public',
  is_moderated BOOLEAN NOT NULL DEFAULT FALSE,
  moderation_flag TEXT,
  resonance_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT wishes_content_not_blank_chk CHECK (btrim(content) <> ''),
  CONSTRAINT wishes_ai_refined_content_not_blank_chk
    CHECK (ai_refined_content IS NULL OR btrim(ai_refined_content) <> ''),
  CONSTRAINT wishes_ai_refinement_consistency_chk
    CHECK (NOT used_ai_refinement OR ai_refined_content IS NOT NULL),
  CONSTRAINT wishes_emotion_score_range_chk
    CHECK (emotion_score >= 0.0 AND emotion_score <= 1.0),
  CONSTRAINT wishes_moderation_flag_not_blank_chk
    CHECK (moderation_flag IS NULL OR btrim(moderation_flag) <> ''),
  CONSTRAINT wishes_resonance_count_nonnegative_chk
    CHECK (resonance_count >= 0)
);

COMMENT ON TABLE wishes IS
  'Short, emotionally expressive posts that power anonymous resonance matching.';
COMMENT ON COLUMN wishes.ai_refined_content IS
  'Optional AI-assisted rewrite used for gentle prompting or safer phrasing.';
COMMENT ON COLUMN wishes.used_ai_refinement IS
  'True when the user accepted or posted an AI-suggested rewrite.';
COMMENT ON COLUMN wishes.emotion_score IS
  'Classifier confidence between 0 and 1 for the assigned emotion label.';
COMMENT ON COLUMN wishes.embedding IS
  '1536-dimensional semantic embedding used for vector similarity search.';
COMMENT ON COLUMN wishes.moderation_flag IS
  'Reason recorded when a wish is flagged by moderation systems or reviewers.';
COMMENT ON COLUMN wishes.resonance_count IS
  'Cached interaction count for fast feed rendering and ranking.';

CREATE TABLE IF NOT EXISTS wish_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wish_id UUID NOT NULL REFERENCES wishes (id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  CONSTRAINT wish_tags_wish_id_tag_key UNIQUE (wish_id, tag),
  CONSTRAINT wish_tags_tag_not_blank_chk CHECK (btrim(tag) <> ''),
  CONSTRAINT wish_tags_tag_normalized_chk CHECK (tag = lower(tag))
);

COMMENT ON TABLE wish_tags IS
  'Theme tags attached to wishes for overlap analysis, search, and narrative grouping.';

CREATE TABLE IF NOT EXISTS interactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  target_wish_id UUID NOT NULL REFERENCES wishes (id) ON DELETE CASCADE,
  type interaction_type_enum NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT interactions_actor_target_type_key UNIQUE (actor_user_id, target_wish_id, type)
);

COMMENT ON TABLE interactions IS
  'Low-friction reactions to wishes that signal resonance, curiosity, and engagement.';

CREATE TABLE IF NOT EXISTS matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id_a UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  user_id_b UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  wish_id_a UUID NOT NULL REFERENCES wishes (id) ON DELETE RESTRICT,
  wish_id_b UUID NOT NULL REFERENCES wishes (id) ON DELETE RESTRICT,
  similarity_score DOUBLE PRECISION NOT NULL,
  shared_themes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  match_status match_status_enum NOT NULL DEFAULT 'pending',
  revealed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT matches_distinct_users_chk CHECK (user_id_a <> user_id_b),
  CONSTRAINT matches_distinct_wishes_chk CHECK (wish_id_a <> wish_id_b),
  CONSTRAINT matches_similarity_score_range_chk
    CHECK (similarity_score >= 0.0 AND similarity_score <= 1.0),
  CONSTRAINT matches_expires_after_create_chk CHECK (expires_at >= created_at)
);

COMMENT ON TABLE matches IS
  'Anonymous pairings between users whose wishes are emotionally and semantically aligned.';
COMMENT ON COLUMN matches.shared_themes IS
  'Overlapping wish tags used to explain why two wishes resonated.';
COMMENT ON COLUMN matches.revealed_at IS
  'Timestamp when a match was opened or identities started to become visible.';

CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL UNIQUE REFERENCES matches (id) ON DELETE CASCADE,
  identity_revealed_a BOOLEAN NOT NULL DEFAULT FALSE,
  identity_revealed_b BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_message_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE conversations IS
  'One-to-one chat threads that open after a match progresses beyond passive resonance.';
COMMENT ON COLUMN conversations.identity_revealed_a IS
  'Whether the first participant has chosen to reveal more of their identity.';
COMMENT ON COLUMN conversations.identity_revealed_b IS
  'Whether the second participant has chosen to reveal more of their identity.';

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  sender_user_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  content TEXT NOT NULL,
  ai_suggested BOOLEAN NOT NULL DEFAULT FALSE,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT messages_content_not_blank_chk CHECK (btrim(content) <> '')
);

COMMENT ON TABLE messages IS
  'Conversation messages exchanged after a match opens.';
COMMENT ON COLUMN messages.ai_suggested IS
  'True when the text was suggested or drafted by an AI assistant.';
COMMENT ON COLUMN messages.is_deleted IS
  'Soft-delete marker that keeps moderation and audit history intact.';

CREATE TABLE IF NOT EXISTS emotional_patterns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
  dominant_emotion TEXT,
  emotion_distribution JSONB NOT NULL DEFAULT '{}'::JSONB,
  top_themes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  wish_count INTEGER NOT NULL DEFAULT 0,
  resonate_given INTEGER NOT NULL DEFAULT 0,
  resonate_received INTEGER NOT NULL DEFAULT 0,
  last_analyzed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT emotional_patterns_distribution_object_chk
    CHECK (jsonb_typeof(emotion_distribution) = 'object'),
  CONSTRAINT emotional_patterns_wish_count_nonnegative_chk CHECK (wish_count >= 0),
  CONSTRAINT emotional_patterns_resonate_given_nonnegative_chk CHECK (resonate_given >= 0),
  CONSTRAINT emotional_patterns_resonate_received_nonnegative_chk CHECK (resonate_received >= 0)
);

COMMENT ON TABLE emotional_patterns IS
  'Pre-aggregated emotional summary per user used for adaptive matching and profile storytelling.';
COMMENT ON COLUMN emotional_patterns.emotion_distribution IS
  'JSON object mapping emotion labels to normalized weighted shares.';
COMMENT ON COLUMN emotional_patterns.top_themes IS
  'Most frequent wish themes derived from the user''s tagged wishes.';

CREATE TABLE IF NOT EXISTS moderation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wish_id UUID REFERENCES wishes (id) ON DELETE SET NULL,
  message_id UUID REFERENCES messages (id) ON DELETE SET NULL,
  triggered_by moderation_trigger_enum NOT NULL,
  reason TEXT NOT NULL,
  action_taken moderation_action_enum NOT NULL,
  reviewed_by_admin BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT moderation_logs_reason_not_blank_chk CHECK (btrim(reason) <> ''),
  CONSTRAINT moderation_logs_target_presence_chk
    CHECK (num_nonnulls(wish_id, message_id) >= 1)
);

COMMENT ON TABLE moderation_logs IS
  'Immutable moderation audit trail covering wishes and conversation messages.';

CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id UUID NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  reported_user_id UUID REFERENCES users (id) ON DELETE SET NULL,
  reported_wish_id UUID REFERENCES wishes (id) ON DELETE SET NULL,
  reported_message_id UUID REFERENCES messages (id) ON DELETE SET NULL,
  reason TEXT NOT NULL,
  status report_status_enum NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT reports_reason_not_blank_chk CHECK (btrim(reason) <> ''),
  CONSTRAINT reports_target_presence_chk
    CHECK (num_nonnulls(reported_user_id, reported_wish_id, reported_message_id) >= 1)
);

COMMENT ON TABLE reports IS
  'User-submitted safety and quality reports routed into review workflows.';

CREATE TABLE IF NOT EXISTS blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  blocked_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT blocks_unique_pair_key UNIQUE (blocker_user_id, blocked_user_id),
  CONSTRAINT blocks_distinct_users_chk CHECK (blocker_user_id <> blocked_user_id)
);

COMMENT ON TABLE blocks IS
  'Private safety boundaries that prevent future surfacing, matching, and contact.';

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  type notification_type_enum NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  related_entity_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT notifications_title_not_blank_chk CHECK (btrim(title) <> ''),
  CONSTRAINT notifications_body_not_blank_chk CHECK (btrim(body) <> '')
);

COMMENT ON TABLE notifications IS
  'Per-user inbox of product, match, and safety notifications.';
COMMENT ON COLUMN notifications.related_entity_id IS
  'Polymorphic pointer to the relevant wish, match, message, or workflow record.';

CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  plan subscription_plan_enum NOT NULL,
  feature_flags JSONB NOT NULL DEFAULT '{}'::JSONB,
  stripe_subscription_id TEXT UNIQUE,
  started_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT subscriptions_feature_flags_object_chk
    CHECK (jsonb_typeof(feature_flags) = 'object'),
  CONSTRAINT subscriptions_stripe_id_not_blank_chk
    CHECK (stripe_subscription_id IS NULL OR btrim(stripe_subscription_id) <> ''),
  CONSTRAINT subscriptions_window_chk
    CHECK (expires_at IS NULL OR expires_at >= started_at)
);

COMMENT ON TABLE subscriptions IS
  'Billing and entitlement history for free and premium access plans.';
COMMENT ON COLUMN subscriptions.feature_flags IS
  'Feature toggles materialized at subscription creation for deterministic entitlement checks.';

CREATE TABLE IF NOT EXISTS aura_customizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
  glow_color TEXT NOT NULL,
  particle_style particle_style_enum NOT NULL,
  animation_speed animation_speed_enum NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT aura_customizations_glow_color_not_blank_chk CHECK (btrim(glow_color) <> ''),
  CONSTRAINT aura_customizations_glow_color_format_chk
    CHECK (
      glow_color ~ '^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})$'
      OR glow_color ~ '^[a-z_]+$'
    )
);

COMMENT ON TABLE aura_customizations IS
  'Premium visual personalization settings used to theme a user''s anonymous presence.';

COMMIT;
