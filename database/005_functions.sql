CREATE OR REPLACE FUNCTION app_current_user_id()
RETURNS UUID
LANGUAGE SQL
STABLE
AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID
$$;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION generate_anonymous_name()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  word_pool TEXT[] := ARRAY[
    'Echo', 'Tide', 'Nova', 'Sol', 'Willow', 'Comet', 'Ember', 'Drift',
    'Lumen', 'Harbor', 'Saffron', 'Rain', 'Cedar', 'Orbit', 'Meadow',
    'Quartz', 'Aurora', 'Bloom', 'Atlas', 'Mirage', 'Velvet', 'Juniper',
    'Aster', 'Dawn', 'River', 'Cinder', 'Halo', 'Lyric'
  ];
  attempt_counter INTEGER := 0;
  candidate TEXT;
BEGIN
  LOOP
    attempt_counter := attempt_counter + 1;

    candidate := word_pool[1 + FLOOR(random() * array_length(word_pool, 1))::INTEGER]
      || '_' ||
      LPAD((10 + FLOOR(random() * 90))::INTEGER::TEXT, 2, '0');

    IF NOT EXISTS (SELECT 1 FROM users WHERE anonymous_name = candidate) THEN
      RETURN candidate;
    END IF;

    EXIT WHEN attempt_counter >= 100;
  END LOOP;

  LOOP
    candidate := word_pool[1 + FLOOR(random() * array_length(word_pool, 1))::INTEGER]
      || '_' ||
      UPPER(SUBSTRING(REPLACE(uuid_generate_v4()::TEXT, '-', '') FROM 1 FOR 6));

    IF NOT EXISTS (SELECT 1 FROM users WHERE anonymous_name = candidate) THEN
      RETURN candidate;
    END IF;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION generate_anonymous_name() IS
  'Returns a unique anonymous display handle such as Echo_47, retrying until an unused value is found.';

CREATE OR REPLACE FUNCTION set_user_anonymous_name()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.anonymous_name IS NULL OR btrim(NEW.anonymous_name) = '' THEN
    NEW.anonymous_name := generate_anonymous_name();
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION find_resonant_matches(p_wish_id UUID, p_limit INTEGER DEFAULT 10)
RETURNS TABLE (
  source_wish_id UUID,
  candidate_wish_id UUID,
  source_user_id UUID,
  candidate_user_id UUID,
  candidate_anonymous_name TEXT,
  similarity_score DOUBLE PRECISION,
  shared_themes TEXT[],
  candidate_emotion_label wish_emotion_enum,
  candidate_created_at TIMESTAMPTZ,
  candidate_is_premium BOOLEAN
)
LANGUAGE SQL
STABLE
AS $$
  WITH base_wish AS (
    SELECT w.id, w.user_id, w.embedding
    FROM wishes w
    WHERE w.id = p_wish_id
      AND w.embedding IS NOT NULL
      AND w.visibility = 'public'
      AND NOT w.is_moderated
  )
  SELECT
    base_wish.id AS source_wish_id,
    candidate.id AS candidate_wish_id,
    base_wish.user_id AS source_user_id,
    candidate.user_id AS candidate_user_id,
    candidate_user.anonymous_name AS candidate_anonymous_name,
    GREATEST(0.0, LEAST(1.0, 1 - (base_wish.embedding <=> candidate.embedding))) AS similarity_score,
    COALESCE(overlap.shared_themes, ARRAY[]::TEXT[]) AS shared_themes,
    candidate.emotion_label AS candidate_emotion_label,
    candidate.created_at AS candidate_created_at,
    (
      (candidate_user.is_premium AND (candidate_user.premium_expires_at IS NULL OR candidate_user.premium_expires_at > CURRENT_TIMESTAMP))
      OR EXISTS (
        SELECT 1
        FROM subscriptions s
        WHERE s.user_id = candidate_user.id
          AND s.plan = 'premium'
          AND s.started_at <= CURRENT_TIMESTAMP
          AND (s.expires_at IS NULL OR s.expires_at > CURRENT_TIMESTAMP)
      )
    ) AS candidate_is_premium
  FROM base_wish
  JOIN wishes candidate
    ON candidate.id <> base_wish.id
   AND candidate.user_id <> base_wish.user_id
   AND candidate.embedding IS NOT NULL
   AND candidate.visibility = 'public'
   AND NOT candidate.is_moderated
  JOIN users candidate_user
    ON candidate_user.id = candidate.user_id
   AND NOT candidate_user.is_banned
  LEFT JOIN LATERAL (
    SELECT ARRAY(
      SELECT DISTINCT wt.tag
      FROM wish_tags wt
      JOIN wish_tags base_tag
        ON base_tag.tag = wt.tag
       AND base_tag.wish_id = base_wish.id
      WHERE wt.wish_id = candidate.id
      ORDER BY 1
    ) AS shared_themes
  ) overlap ON TRUE
  WHERE NOT EXISTS (
      SELECT 1
      FROM blocks b
      WHERE (b.blocker_user_id = base_wish.user_id AND b.blocked_user_id = candidate.user_id)
         OR (b.blocker_user_id = candidate.user_id AND b.blocked_user_id = base_wish.user_id)
    )
    AND NOT EXISTS (
      SELECT 1
      FROM matches m
      WHERE m.match_status IN ('pending', 'opened')
        AND (
          (m.wish_id_a = base_wish.id AND m.wish_id_b = candidate.id)
          OR (m.wish_id_a = candidate.id AND m.wish_id_b = base_wish.id)
          OR (
            LEAST(m.user_id_a, m.user_id_b) = LEAST(base_wish.user_id, candidate.user_id)
            AND GREATEST(m.user_id_a, m.user_id_b) = GREATEST(base_wish.user_id, candidate.user_id)
          )
        )
    )
  ORDER BY
    candidate_is_premium DESC,
    similarity_score DESC,
    cardinality(COALESCE(overlap.shared_themes, ARRAY[]::TEXT[])) DESC,
    candidate.created_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 10), 1);
$$;

COMMENT ON FUNCTION find_resonant_matches(UUID, INTEGER) IS
  'Ranks candidate wishes by cosine similarity while filtering self-matches, blocks, and active existing matches.';

CREATE OR REPLACE FUNCTION create_match_from_wishes(p_wish_id_a UUID, p_wish_id_b UUID)
RETURNS matches
LANGUAGE plpgsql
AS $$
DECLARE
  wish_a wishes%ROWTYPE;
  wish_b wishes%ROWTYPE;
  ordered_user_id_a UUID;
  ordered_user_id_b UUID;
  ordered_wish_id_a UUID;
  ordered_wish_id_b UUID;
  v_similarity_score DOUBLE PRECISION;
  v_shared_themes TEXT[] := ARRAY[]::TEXT[];
  v_match matches%ROWTYPE;
BEGIN
  IF p_wish_id_a = p_wish_id_b THEN
    RAISE EXCEPTION 'Cannot create a match from the same wish twice.';
  END IF;

  SELECT * INTO wish_a FROM wishes WHERE id = p_wish_id_a;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wish % does not exist.', p_wish_id_a;
  END IF;

  SELECT * INTO wish_b FROM wishes WHERE id = p_wish_id_b;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wish % does not exist.', p_wish_id_b;
  END IF;

  IF wish_a.user_id = wish_b.user_id THEN
    RAISE EXCEPTION 'Matches must involve two different users.';
  END IF;

  IF wish_a.embedding IS NULL OR wish_b.embedding IS NULL THEN
    RAISE EXCEPTION 'Both wishes must have embeddings before creating a match.';
  END IF;

  IF wish_a.visibility <> 'public' OR wish_b.visibility <> 'public' THEN
    RAISE EXCEPTION 'Only public wishes can enter the active matching pool.';
  END IF;

  IF wish_a.is_moderated OR wish_b.is_moderated THEN
    RAISE EXCEPTION 'Moderated wishes cannot be matched.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM blocks b
    WHERE (b.blocker_user_id = wish_a.user_id AND b.blocked_user_id = wish_b.user_id)
       OR (b.blocker_user_id = wish_b.user_id AND b.blocked_user_id = wish_a.user_id)
  ) THEN
    RAISE EXCEPTION 'Users with an active block relationship cannot be matched.';
  END IF;

  IF wish_a.user_id::TEXT <= wish_b.user_id::TEXT THEN
    ordered_user_id_a := wish_a.user_id;
    ordered_user_id_b := wish_b.user_id;
    ordered_wish_id_a := wish_a.id;
    ordered_wish_id_b := wish_b.id;
  ELSE
    ordered_user_id_a := wish_b.user_id;
    ordered_user_id_b := wish_a.user_id;
    ordered_wish_id_a := wish_b.id;
    ordered_wish_id_b := wish_a.id;
  END IF;

  SELECT m.*
  INTO v_match
  FROM matches m
  WHERE m.match_status IN ('pending', 'opened')
    AND LEAST(m.user_id_a, m.user_id_b) = LEAST(ordered_user_id_a, ordered_user_id_b)
    AND GREATEST(m.user_id_a, m.user_id_b) = GREATEST(ordered_user_id_a, ordered_user_id_b)
  ORDER BY m.created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN v_match;
  END IF;

  v_similarity_score := GREATEST(0.0, LEAST(1.0, 1 - (wish_a.embedding <=> wish_b.embedding)));

  SELECT COALESCE(ARRAY(
    SELECT shared.tag
    FROM (
      SELECT tag FROM wish_tags WHERE wish_id = ordered_wish_id_a
      INTERSECT
      SELECT tag FROM wish_tags WHERE wish_id = ordered_wish_id_b
    ) AS shared(tag)
    ORDER BY shared.tag
  ), ARRAY[]::TEXT[])
  INTO v_shared_themes;

  BEGIN
    INSERT INTO matches (
      user_id_a,
      user_id_b,
      wish_id_a,
      wish_id_b,
      similarity_score,
      shared_themes,
      match_status,
      expires_at
    )
    VALUES (
      ordered_user_id_a,
      ordered_user_id_b,
      ordered_wish_id_a,
      ordered_wish_id_b,
      v_similarity_score,
      v_shared_themes,
      'pending',
      CURRENT_TIMESTAMP + INTERVAL '7 days'
    )
    RETURNING * INTO v_match;
  EXCEPTION
    WHEN unique_violation THEN
      SELECT m.*
      INTO v_match
      FROM matches m
      WHERE m.match_status IN ('pending', 'opened')
        AND LEAST(m.user_id_a, m.user_id_b) = LEAST(ordered_user_id_a, ordered_user_id_b)
        AND GREATEST(m.user_id_a, m.user_id_b) = GREATEST(ordered_user_id_a, ordered_user_id_b)
      ORDER BY m.created_at DESC
      LIMIT 1;
  END;

  RETURN v_match;
END;
$$;

COMMENT ON FUNCTION create_match_from_wishes(UUID, UUID) IS
  'Creates a pending match from two compatible wishes and relies on the match trigger to notify both users.';

CREATE OR REPLACE FUNCTION update_emotional_patterns(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_dominant_emotion TEXT;
  v_emotion_distribution JSONB := '{}'::JSONB;
  v_top_themes TEXT[] := ARRAY[]::TEXT[];
  v_wish_count INTEGER := 0;
  v_resonate_given INTEGER := 0;
  v_resonate_received INTEGER := 0;
BEGIN
  SELECT COUNT(*)
  INTO v_wish_count
  FROM wishes w
  WHERE w.user_id = p_user_id
    AND w.visibility <> 'deleted';

  WITH weighted_emotions AS (
    SELECT w.emotion_label::TEXT AS emotion_label, SUM(w.emotion_score) AS weight
    FROM wishes w
    WHERE w.user_id = p_user_id
      AND w.visibility <> 'deleted'
    GROUP BY w.emotion_label
  ),
  totals AS (
    SELECT SUM(weight) AS total_weight
    FROM weighted_emotions
  )
  SELECT
    (
      SELECT emotion_label
      FROM weighted_emotions
      ORDER BY weight DESC, emotion_label
      LIMIT 1
    ),
    COALESCE(
      (
        SELECT jsonb_object_agg(
          emotion_label,
          ROUND((weight / NULLIF(total_weight, 0))::NUMERIC, 4)
        )
        FROM weighted_emotions, totals
      ),
      '{}'::JSONB
    )
  INTO v_dominant_emotion, v_emotion_distribution;

  SELECT COALESCE(ARRAY(
    SELECT wt.tag
    FROM wishes w
    JOIN wish_tags wt ON wt.wish_id = w.id
    WHERE w.user_id = p_user_id
      AND w.visibility <> 'deleted'
    GROUP BY wt.tag
    ORDER BY COUNT(*) DESC, wt.tag
    LIMIT 5
  ), ARRAY[]::TEXT[])
  INTO v_top_themes;

  SELECT COUNT(*)
  INTO v_resonate_given
  FROM interactions i
  WHERE i.actor_user_id = p_user_id
    AND i.type = 'resonate';

  SELECT COUNT(*)
  INTO v_resonate_received
  FROM interactions i
  JOIN wishes w ON w.id = i.target_wish_id
  WHERE w.user_id = p_user_id
    AND i.type = 'resonate';

  INSERT INTO emotional_patterns (
    user_id,
    dominant_emotion,
    emotion_distribution,
    top_themes,
    wish_count,
    resonate_given,
    resonate_received,
    last_analyzed_at,
    updated_at
  )
  VALUES (
    p_user_id,
    v_dominant_emotion,
    v_emotion_distribution,
    v_top_themes,
    v_wish_count,
    v_resonate_given,
    v_resonate_received,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  )
  ON CONFLICT (user_id) DO UPDATE
  SET dominant_emotion = EXCLUDED.dominant_emotion,
      emotion_distribution = EXCLUDED.emotion_distribution,
      top_themes = EXCLUDED.top_themes,
      wish_count = EXCLUDED.wish_count,
      resonate_given = EXCLUDED.resonate_given,
      resonate_received = EXCLUDED.resonate_received,
      last_analyzed_at = EXCLUDED.last_analyzed_at,
      updated_at = CURRENT_TIMESTAMP;
END;
$$;

COMMENT ON FUNCTION update_emotional_patterns(UUID) IS
  'Refreshes the denormalized emotional summary for a user from wishes, wish tags, and resonance activity.';

CREATE OR REPLACE FUNCTION soft_delete_wish(p_wish_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  UPDATE wishes
  SET visibility = 'deleted',
      updated_at = CURRENT_TIMESTAMP
  WHERE id = p_wish_id
    AND visibility <> 'deleted'
  RETURNING user_id INTO v_user_id;

  IF v_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  UPDATE matches
  SET match_status = 'expired'
  WHERE match_status = 'pending'
    AND (wish_id_a = p_wish_id OR wish_id_b = p_wish_id);

  PERFORM update_emotional_patterns(v_user_id);

  RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION soft_delete_wish(UUID) IS
  'Soft-deletes a wish, removes it from future matching, and preserves the record for audit history.';

CREATE OR REPLACE FUNCTION check_daily_wish_limit(p_user_id UUID)
RETURNS TABLE (can_post BOOLEAN, remaining INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_premium BOOLEAN := FALSE;
  v_daily_limit INTEGER := 3;
  v_today_count INTEGER := 0;
  v_day_start_utc TIMESTAMPTZ;
BEGIN
  v_day_start_utc := (date_trunc('day', CURRENT_TIMESTAMP AT TIME ZONE 'UTC')) AT TIME ZONE 'UTC';

  SELECT
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
    )
  INTO v_is_premium
  FROM users u
  WHERE u.id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User % does not exist.', p_user_id;
  END IF;

  IF v_is_premium THEN
    RETURN QUERY SELECT TRUE, NULL::INTEGER;
    RETURN;
  END IF;

  SELECT COUNT(*)
  INTO v_today_count
  FROM wishes w
  WHERE w.user_id = p_user_id
    AND w.created_at >= v_day_start_utc;

  RETURN QUERY
  SELECT v_today_count < v_daily_limit, GREATEST(v_daily_limit - v_today_count, 0);
END;
$$;

COMMENT ON FUNCTION check_daily_wish_limit(UUID) IS
  'Returns whether the user can post another wish today. Remaining is NULL for premium users with unlimited posting.';

CREATE OR REPLACE FUNCTION expire_old_matches()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_expired_count INTEGER := 0;
BEGIN
  UPDATE matches
  SET match_status = 'expired'
  WHERE match_status = 'pending'
    AND (
      expires_at <= CURRENT_TIMESTAMP
      OR created_at <= CURRENT_TIMESTAMP - INTERVAL '7 days'
    );

  GET DIAGNOSTICS v_expired_count = ROW_COUNT;
  RETURN v_expired_count;
END;
$$;

COMMENT ON FUNCTION expire_old_matches() IS
  'Expires stale pending matches and returns the number of rows updated.';

CREATE OR REPLACE FUNCTION enforce_daily_wish_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_can_post BOOLEAN;
  v_remaining INTEGER;
BEGIN
  SELECT can_post, remaining
  INTO v_can_post, v_remaining
  FROM check_daily_wish_limit(NEW.user_id);

  IF NOT v_can_post THEN
    RAISE EXCEPTION 'Daily wish limit exceeded for user %.', NEW.user_id
      USING DETAIL = 'Free users can post at most three wishes per UTC day.',
            HINT = 'Upgrade to premium or wait for the next UTC day window.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION handle_wish_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM update_emotional_patterns(NEW.user_id);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION handle_resonate_interaction()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_owner_user_id UUID;
BEGIN
  UPDATE wishes
  SET resonance_count = resonance_count + 1,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.target_wish_id
  RETURNING user_id INTO v_owner_user_id;

  IF v_owner_user_id IS NOT NULL AND v_owner_user_id <> NEW.actor_user_id THEN
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      related_entity_id
    )
    VALUES (
      v_owner_user_id,
      'resonance',
      'A wish resonated',
      'Someone resonated with one of your wishes.',
      NEW.target_wish_id
    );
  END IF;

  IF v_owner_user_id IS NOT NULL THEN
    PERFORM update_emotional_patterns(v_owner_user_id);
  END IF;

  PERFORM update_emotional_patterns(NEW.actor_user_id);

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_match_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_wish_owner_a UUID;
  v_wish_owner_b UUID;
BEGIN
  SELECT user_id INTO v_wish_owner_a FROM wishes WHERE id = NEW.wish_id_a;
  SELECT user_id INTO v_wish_owner_b FROM wishes WHERE id = NEW.wish_id_b;

  IF v_wish_owner_a IS NULL OR v_wish_owner_b IS NULL THEN
    RAISE EXCEPTION 'Both wishes must exist before creating a match.';
  END IF;

  IF v_wish_owner_a <> NEW.user_id_a OR v_wish_owner_b <> NEW.user_id_b THEN
    RAISE EXCEPTION 'Match users must align with the owners of their respective wishes.';
  END IF;

  IF NEW.user_id_a::TEXT > NEW.user_id_b::TEXT THEN
    RAISE EXCEPTION 'Matches must be stored in canonical user order.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION handle_match_notifications()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_name_a TEXT;
  v_name_b TEXT;
BEGIN
  SELECT anonymous_name INTO v_name_a FROM users WHERE id = NEW.user_id_a;
  SELECT anonymous_name INTO v_name_b FROM users WHERE id = NEW.user_id_b;

  INSERT INTO notifications (user_id, type, title, body, related_entity_id)
  VALUES
    (
      NEW.user_id_a,
      'new_match',
      'A new match surfaced',
      FORMAT('Your wish aligned with %s. Open it before it fades.', COALESCE(v_name_b, 'someone new')),
      NEW.id
    ),
    (
      NEW.user_id_b,
      'new_match',
      'A new match surfaced',
      FORMAT('Your wish aligned with %s. Open it before it fades.', COALESCE(v_name_a, 'someone new')),
      NEW.id
    );

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION validate_message_sender()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM conversations c
    JOIN matches m ON m.id = c.match_id
    WHERE c.id = NEW.conversation_id
      AND c.is_active
      AND NEW.sender_user_id IN (m.user_id_a, m.user_id_b)
  ) THEN
    RAISE EXCEPTION 'Message sender must be an active participant in the target conversation.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION touch_conversation_last_message()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_conversation_id UUID := COALESCE(NEW.conversation_id, OLD.conversation_id);
BEGIN
  UPDATE conversations c
  SET last_message_at = (
    SELECT MAX(m.sent_at)
    FROM messages m
    WHERE m.conversation_id = v_conversation_id
      AND NOT m.is_deleted
  )
  WHERE c.id = v_conversation_id;

  RETURN COALESCE(NEW, OLD);
END;
$$;
