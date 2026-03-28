CREATE OR REPLACE VIEW v_public_wish_feed AS
SELECT
  w.id AS wish_id,
  u.anonymous_name,
  COALESCE(w.ai_refined_content, w.content) AS display_content,
  w.emotion_label,
  w.emotion_score,
  w.resonance_count,
  COALESCE(array_agg(DISTINCT wt.tag) FILTER (WHERE wt.tag IS NOT NULL), ARRAY[]::TEXT[]) AS tags,
  w.created_at
FROM wishes w
JOIN users u ON u.id = w.user_id
LEFT JOIN wish_tags wt ON wt.wish_id = w.id
WHERE w.visibility = 'public'
  AND NOT w.is_moderated
  AND NOT u.is_banned
GROUP BY
  w.id,
  u.anonymous_name,
  COALESCE(w.ai_refined_content, w.content),
  w.emotion_label,
  w.emotion_score,
  w.resonance_count,
  w.created_at
ORDER BY w.created_at DESC;

CREATE OR REPLACE VIEW v_user_emotional_summary AS
SELECT
  u.id AS user_id,
  u.anonymous_name,
  u.intent,
  u.current_mood,
  (
    (u.is_premium AND (u.premium_expires_at IS NULL OR u.premium_expires_at > CURRENT_TIMESTAMP))
    OR EXISTS (
      SELECT 1
      FROM subscriptions s
      WHERE s.user_id = u.id
        AND s.plan = 'premium'
        AND s.started_at <= CURRENT_TIMESTAMP
        AND (s.expires_at IS NULL OR s.expires_at > CURRENT_TIMESTAMP)
    )
  ) AS has_active_premium,
  ep.dominant_emotion,
  ep.emotion_distribution,
  ep.top_themes,
  ep.wish_count,
  ep.resonate_given,
  ep.resonate_received,
  ep.last_analyzed_at
FROM users u
LEFT JOIN emotional_patterns ep ON ep.user_id = u.id
WHERE NOT u.is_banned;

CREATE OR REPLACE VIEW v_active_matches AS
SELECT
  m.id AS match_id,
  ua.anonymous_name AS anonymous_name_a,
  ub.anonymous_name AS anonymous_name_b,
  m.similarity_score,
  m.shared_themes,
  m.revealed_at,
  m.expires_at,
  m.created_at,
  c.id AS conversation_id,
  c.is_active AS conversation_active,
  c.identity_revealed_a,
  c.identity_revealed_b,
  c.last_message_at
FROM matches m
JOIN users ua ON ua.id = m.user_id_a
JOIN users ub ON ub.id = m.user_id_b
LEFT JOIN conversations c ON c.match_id = m.id
WHERE m.match_status = 'opened';

CREATE OR REPLACE VIEW v_match_graph AS
SELECT
  m.id AS match_id,
  m.match_status,
  m.similarity_score,
  m.shared_themes,
  ua.id AS node_a_user_id,
  ua.anonymous_name AS node_a_name,
  ub.id AS node_b_user_id,
  ub.anonymous_name AS node_b_name,
  m.created_at
FROM matches m
JOIN users ua ON ua.id = m.user_id_a
JOIN users ub ON ub.id = m.user_id_b;
