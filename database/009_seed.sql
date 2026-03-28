BEGIN;

CREATE OR REPLACE FUNCTION seed_placeholder_embedding(p_seed INTEGER)
RETURNS VECTOR(1536)
LANGUAGE SQL
IMMUTABLE
AS $$
  WITH dims AS (
    SELECT generate_series(1, 1536) AS idx
  )
  SELECT (
    '[' || string_agg(
      to_char(
        (
          (
            sin((p_seed * 0.73) + (idx * 0.019))
            + cos((p_seed * 0.37) + (idx * 0.011))
          ) / 4.0
        )::NUMERIC,
        'FM0.000000'
      ),
      ','
      ORDER BY idx
    ) || ']'
  )::VECTOR(1536)
  FROM dims;
$$;

CREATE TEMP TABLE seed_users (
  anonymous_name TEXT,
  email_plain TEXT,
  intent user_intent_enum,
  current_mood TEXT,
  is_premium BOOLEAN,
  premium_days INTEGER
) ON COMMIT DROP;

INSERT INTO seed_users (anonymous_name, email_plain, intent, current_mood, is_premium, premium_days)
VALUES
  ('Echo_47', 'alba.rivera@example.com', 'connect', 'Hopeful', TRUE, 90),
  ('Tide_19', 'miles.cho@example.com', 'explore', 'Restless but open', FALSE, 0),
  ('Nova_08', 'lena.hart@example.com', 'express', 'Tender', FALSE, 0),
  ('Sol_31', 'ari.kim@example.com', 'connect', 'Grounded', TRUE, 90),
  ('Willow_22', 'zoe.bennett@example.com', 'express', 'A little lonely', FALSE, 0),
  ('Comet_14', 'jordan.ellis@example.com', 'explore', 'Curious', FALSE, 0),
  ('Ember_63', 'priya.shah@example.com', 'connect', 'Warm', TRUE, 90),
  ('Drift_55', 'marcus.reed@example.com', 'explore', 'Overthinking', FALSE, 0),
  ('Lumen_11', 'aya.nakamura@example.com', 'express', 'Hopeful after a hard week', FALSE, 0),
  ('Harbor_72', 'noah.patel@example.com', 'connect', 'Calm', FALSE, 0),
  ('Saffron_27', 'chloe.martin@example.com', 'explore', 'Creative', TRUE, 90),
  ('Rain_36', 'elias.moore@example.com', 'express', 'Numb but trying', FALSE, 0),
  ('Cedar_41', 'maya.lopez@example.com', 'connect', 'Soft-hearted', FALSE, 0),
  ('Orbit_17', 'dylan.foster@example.com', 'explore', 'Playful', FALSE, 0),
  ('Meadow_90', 'sarah.nguyen@example.com', 'express', 'Healing', FALSE, 0),
  ('Quartz_88', 'mateo.alvarez@example.com', 'connect', 'Steady', TRUE, 90),
  ('Aurora_05', 'jasmine.clark@example.com', 'explore', 'Daydreaming', FALSE, 0),
  ('Bloom_66', 'ethan.turner@example.com', 'express', 'Anxious but optimistic', FALSE, 0),
  ('Atlas_29', 'nora.singh@example.com', 'connect', 'Ready for depth', FALSE, 0),
  ('Mirage_53', 'leo.garcia@example.com', 'explore', 'Reflective', FALSE, 0);

INSERT INTO users (
  id,
  anonymous_name,
  email_hash,
  password_hash,
  intent,
  current_mood,
  is_premium,
  premium_expires_at,
  is_banned,
  created_at,
  updated_at
)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(su.email_plain)) AS user_id,
  su.anonymous_name,
  digest(lower(trim(su.email_plain)), 'sha256') AS email_hash,
  FORMAT(
    '$argon2id$v=19$m=65536,t=3,p=4$seed$%s',
    encode(digest(lower(trim(su.email_plain)) || ':welcome', 'sha256'), 'base64')
  ) AS password_hash,
  su.intent,
  su.current_mood,
  su.is_premium,
  CASE
    WHEN su.is_premium THEN CURRENT_TIMESTAMP + make_interval(days => su.premium_days)
    ELSE NULL
  END AS premium_expires_at,
  FALSE,
  CURRENT_TIMESTAMP - INTERVAL '30 days',
  CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM seed_users su
WHERE NOT EXISTS (
  SELECT 1
  FROM users u
  WHERE u.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(su.email_plain))
);

CREATE TEMP TABLE seed_user_tags (
  email_plain TEXT,
  tags TEXT[]
) ON COMMIT DROP;

INSERT INTO seed_user_tags (email_plain, tags)
VALUES
  ('alba.rivera@example.com', ARRAY['music', 'love', 'walking']),
  ('miles.cho@example.com', ARRAY['anxiety', 'career', 'connection']),
  ('lena.hart@example.com', ARRAY['healing', 'love', 'vulnerability']),
  ('ari.kim@example.com', ARRAY['growth', 'routine', 'trust']),
  ('zoe.bennett@example.com', ARRAY['loneliness', 'love', 'healing']),
  ('jordan.ellis@example.com', ARRAY['curiosity', 'travel', 'career']),
  ('priya.shah@example.com', ARRAY['music', 'love', 'joy']),
  ('marcus.reed@example.com', ARRAY['anxiety', 'humor', 'loneliness']),
  ('aya.nakamura@example.com', ARRAY['healing', 'calm', 'growth']),
  ('noah.patel@example.com', ARRAY['trust', 'connection', 'commitment']),
  ('chloe.martin@example.com', ARRAY['creativity', 'career', 'love']),
  ('elias.moore@example.com', ARRAY['healing', 'stress', 'mental_health']),
  ('maya.lopez@example.com', ARRAY['love', 'self_worth', 'trust']),
  ('dylan.foster@example.com', ARRAY['humor', 'travel', 'dating']),
  ('sarah.nguyen@example.com', ARRAY['healing', 'grief', 'growth']),
  ('mateo.alvarez@example.com', ARRAY['commitment', 'trust', 'peace']),
  ('jasmine.clark@example.com', ARRAY['love', 'communication', 'anxiety']),
  ('ethan.turner@example.com', ARRAY['hope', 'career', 'connection']),
  ('nora.singh@example.com', ARRAY['growth', 'connection', 'vulnerability']),
  ('leo.garcia@example.com', ARRAY['growth', 'adventure', 'self_trust']);

INSERT INTO user_tags (id, user_id, tag, created_at)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user-tag:' || lower(sut.email_plain) || ':' || tag_value.tag),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(sut.email_plain)),
  tag_value.tag,
  CURRENT_TIMESTAMP - INTERVAL '10 days'
FROM seed_user_tags sut
CROSS JOIN LATERAL unnest(sut.tags) AS tag_value(tag)
WHERE NOT EXISTS (
  SELECT 1
  FROM user_tags ut
  WHERE ut.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:user-tag:' || lower(sut.email_plain) || ':' || tag_value.tag)
);

CREATE TEMP TABLE seed_wishes (
  wish_no INTEGER,
  email_plain TEXT,
  content TEXT,
  ai_refined_content TEXT,
  emotion_label wish_emotion_enum,
  emotion_score DOUBLE PRECISION,
  visibility wish_visibility_enum,
  is_moderated BOOLEAN,
  moderation_flag TEXT,
  tags TEXT[],
  hours_ago INTEGER
) ON COMMIT DROP;

INSERT INTO seed_wishes (
  wish_no,
  email_plain,
  content,
  ai_refined_content,
  emotion_label,
  emotion_score,
  visibility,
  is_moderated,
  moderation_flag,
  tags,
  hours_ago
)
VALUES
  (1, 'alba.rivera@example.com', 'I wish someone loved late-night walks as much as I do.', 'I''m hoping to meet someone who finds peace in late-night walks.', 'love', 0.92, 'public', FALSE, NULL, ARRAY['love', 'walking', 'calm'], 4),
  (2, 'alba.rivera@example.com', 'I wish I could tell someone how much music steadies me.', NULL, 'joy', 0.81, 'public', FALSE, NULL, ARRAY['music', 'stress', 'growth'], 10),
  (3, 'alba.rivera@example.com', 'I wish emotional honesty felt less rare.', NULL, 'sadness', 0.74, 'public', FALSE, NULL, ARRAY['growth', 'love', 'vulnerability'], 28),
  (4, 'miles.cho@example.com', 'I wish I knew how to quiet my brain after midnight.', 'I''m looking for someone who understands midnight overthinking without judgment.', 'anxiety', 0.91, 'public', FALSE, NULL, ARRAY['anxiety', 'sleep', 'stress'], 5),
  (5, 'miles.cho@example.com', 'I wish someone wanted slow conversations with zero pressure.', NULL, 'curiosity', 0.79, 'public', FALSE, NULL, ARRAY['connection', 'slow_dating', 'vulnerability'], 14),
  (6, 'miles.cho@example.com', 'I wish career ambition did not make me feel distant from people.', NULL, 'sadness', 0.68, 'public', FALSE, NULL, ARRAY['career', 'loneliness', 'growth'], 40),
  (7, 'lena.hart@example.com', 'I wish it was easier to say I am still healing from an old heartbreak.', 'I''m still healing from heartbreak and want a space where that can be spoken gently.', 'sadness', 0.93, 'public', FALSE, NULL, ARRAY['love', 'healing', 'vulnerability'], 8),
  (8, 'lena.hart@example.com', 'I wish tenderness was not mistaken for weakness.', NULL, 'sadness', 0.83, 'public', FALSE, NULL, ARRAY['growth', 'self_worth', 'love'], 18),
  (9, 'lena.hart@example.com', 'I wish I could send one tiny thank-you to the person who taught me softness.', NULL, 'love', 0.86, 'public', FALSE, NULL, ARRAY['gratitude', 'love', 'growth'], 48),
  (10, 'ari.kim@example.com', 'I wish I could meet someone who likes building routines together.', 'I would love to meet someone who finds comfort in building rituals together.', 'love', 0.84, 'public', FALSE, NULL, ARRAY['routine', 'growth', 'connection'], 3),
  (11, 'ari.kim@example.com', 'I wish more people asked what peace feels like instead of what success looks like.', NULL, 'curiosity', 0.77, 'public', FALSE, NULL, ARRAY['career', 'peace', 'growth'], 16),
  (12, 'ari.kim@example.com', 'I wish trust could grow without games.', NULL, 'love', 0.88, 'public', FALSE, NULL, ARRAY['trust', 'love', 'dating'], 36),
  (13, 'zoe.bennett@example.com', 'I wish loneliness did not echo so loudly in the mornings.', 'Some mornings feel louder than I want them to, and I wish loneliness did not fill the room.', 'sadness', 0.90, 'public', FALSE, NULL, ARRAY['loneliness', 'morning', 'anxiety'], 7),
  (14, 'zoe.bennett@example.com', 'I wish I could feel chosen without pretending I am fine.', NULL, 'sadness', 0.88, 'public', FALSE, NULL, ARRAY['love', 'vulnerability', 'loneliness'], 20),
  (15, 'zoe.bennett@example.com', 'I wish healing looked less invisible.', NULL, 'neutral', 0.69, 'public', FALSE, NULL, ARRAY['healing', 'growth', 'stress'], 42),
  (16, 'jordan.ellis@example.com', 'I wish curiosity about someone could feel safe again.', NULL, 'curiosity', 0.82, 'public', FALSE, NULL, ARRAY['curiosity', 'dating', 'trust'], 6),
  (17, 'jordan.ellis@example.com', 'I wish there were more spaces where weird questions were welcome.', NULL, 'joy', 0.73, 'public', FALSE, NULL, ARRAY['growth', 'curiosity', 'humor'], 17),
  (18, 'jordan.ellis@example.com', 'I wish work did not swallow the part of me that wants adventure.', NULL, 'anxiety', 0.70, 'archived', FALSE, NULL, ARRAY['career', 'travel', 'stress'], 33),
  (19, 'priya.shah@example.com', 'I wish someone would dance with me in the kitchen after a hard day.', 'I''m hoping for a connection that can turn an ordinary night into warmth.', 'joy', 0.95, 'public', FALSE, NULL, ARRAY['love', 'joy', 'music'], 2),
  (20, 'priya.shah@example.com', 'I wish softness and strength were seen as the same thing.', NULL, 'love', 0.85, 'public', FALSE, NULL, ARRAY['growth', 'love', 'self_worth'], 12),
  (21, 'priya.shah@example.com', 'I wish I could meet a heart that knows how to stay.', NULL, 'love', 0.91, 'public', FALSE, NULL, ARRAY['love', 'commitment', 'trust'], 26),
  (22, 'marcus.reed@example.com', 'I wish overthinking came with an off switch.', NULL, 'anxiety', 0.94, 'public', FALSE, NULL, ARRAY['anxiety', 'stress', 'mental_health'], 5),
  (23, 'marcus.reed@example.com', 'I wish I did not feel like the funny friend and the lonely one at the same time.', NULL, 'sadness', 0.80, 'public', FALSE, NULL, ARRAY['loneliness', 'humor', 'self_worth'], 15),
  (24, 'marcus.reed@example.com', 'I wish someone would ask me what I am afraid of and actually wait for the answer.', 'I want the kind of conversation where fear can be named and held.', 'curiosity', 0.78, 'public', FALSE, NULL, ARRAY['vulnerability', 'anxiety', 'connection'], 29),
  (25, 'aya.nakamura@example.com', 'I wish hope did not feel naive after disappointment.', NULL, 'sadness', 0.76, 'public', FALSE, NULL, ARRAY['hope', 'healing', 'growth'], 9),
  (26, 'aya.nakamura@example.com', 'I wish I could bottle the calm I feel near water.', NULL, 'joy', 0.71, 'public', FALSE, NULL, ARRAY['calm', 'nature', 'healing'], 21),
  (27, 'aya.nakamura@example.com', 'I wish people understood how brave small recoveries are.', NULL, 'joy', 0.69, 'public', FALSE, NULL, ARRAY['growth', 'healing', 'gratitude'], 45),
  (28, 'noah.patel@example.com', 'I wish love felt like a harbor and not a test.', NULL, 'love', 0.89, 'public', FALSE, NULL, ARRAY['love', 'trust', 'peace'], 11),
  (29, 'noah.patel@example.com', 'I wish I knew which parts of me are still guarded.', 'I''m trying to understand which parts of me still brace before closeness.', 'curiosity', 0.75, 'public', FALSE, NULL, ARRAY['growth', 'vulnerability', 'trust'], 22),
  (30, 'noah.patel@example.com', 'I wish someone wanted consistency more than sparks.', NULL, 'love', 0.82, 'public', FALSE, NULL, ARRAY['dating', 'commitment', 'connection'], 41),
  (31, 'chloe.martin@example.com', 'I wish creativity could be a first language in a relationship.', NULL, 'curiosity', 0.84, 'public', FALSE, NULL, ARRAY['creativity', 'love', 'growth'], 6),
  (32, 'chloe.martin@example.com', 'I wish the right person would understand my quiet seasons.', NULL, 'love', 0.80, 'public', FALSE, NULL, ARRAY['love', 'loneliness', 'healing'], 19),
  (33, 'chloe.martin@example.com', 'I wish my ambition and softness did not feel like opposites.', NULL, 'curiosity', 0.72, 'public', FALSE, NULL, ARRAY['career', 'self_worth', 'growth'], 35),
  (34, 'elias.moore@example.com', 'I wish numbness had a gentler exit.', NULL, 'sadness', 0.87, 'public', TRUE, 'wellbeing_review', ARRAY['healing', 'stress', 'mental_health'], 13),
  (35, 'elias.moore@example.com', 'I wish I could remember what excitement felt like before burnout.', NULL, 'sadness', 0.79, 'archived', FALSE, NULL, ARRAY['career', 'stress', 'healing'], 32),
  (36, 'elias.moore@example.com', 'I wish I had words for the kind of care I need.', 'I''m trying to find language for the kind of care that would actually help.', 'curiosity', 0.74, 'public', FALSE, NULL, ARRAY['vulnerability', 'connection', 'growth'], 43),
  (37, 'maya.lopez@example.com', 'I wish love could arrive without me bracing for loss.', NULL, 'anxiety', 0.83, 'public', FALSE, NULL, ARRAY['love', 'anxiety', 'trust'], 9),
  (38, 'maya.lopez@example.com', 'I wish I could stop apologizing for feeling deeply.', NULL, 'love', 0.77, 'public', FALSE, NULL, ARRAY['self_worth', 'growth', 'love'], 23),
  (39, 'maya.lopez@example.com', 'I wish someone cherished slow mornings and honest check-ins.', NULL, 'love', 0.90, 'public', FALSE, NULL, ARRAY['love', 'connection', 'morning'], 46),
  (40, 'dylan.foster@example.com', 'I wish flirting could be playful without being shallow.', NULL, 'joy', 0.78, 'public', FALSE, NULL, ARRAY['dating', 'humor', 'connection'], 8),
  (41, 'dylan.foster@example.com', 'I wish road trips with the right person were in my near future.', NULL, 'joy', 0.81, 'public', FALSE, NULL, ARRAY['travel', 'joy', 'love'], 24),
  (42, 'dylan.foster@example.com', 'I wish I trusted calm more than chaos.', NULL, 'anxiety', 0.73, 'public', FALSE, NULL, ARRAY['growth', 'anxiety', 'healing'], 44),
  (43, 'sarah.nguyen@example.com', 'I wish healing was not so lonely in the middle.', 'Healing feels loneliest in the middle, and I wish that part was shared more often.', 'sadness', 0.88, 'public', FALSE, NULL, ARRAY['healing', 'loneliness', 'growth'], 7),
  (44, 'sarah.nguyen@example.com', 'I wish there were language for the kind of grief that does not have a funeral.', NULL, 'sadness', 0.91, 'public', FALSE, NULL, ARRAY['grief', 'healing', 'loss'], 27),
  (45, 'sarah.nguyen@example.com', 'I wish someone would notice how hard I am trying.', NULL, 'sadness', 0.70, 'public', FALSE, NULL, ARRAY['vulnerability', 'self_worth', 'connection'], 47),
  (46, 'mateo.alvarez@example.com', 'I wish loyalty felt modern again.', 'I still believe loyalty can feel fresh, intentional, and deeply attractive.', 'love', 0.86, 'public', FALSE, NULL, ARRAY['commitment', 'trust', 'love'], 10),
  (47, 'mateo.alvarez@example.com', 'I wish I could share silence with someone and still feel understood.', NULL, 'love', 0.88, 'public', FALSE, NULL, ARRAY['connection', 'peace', 'love'], 25),
  (48, 'mateo.alvarez@example.com', 'I wish my steady nature felt exciting to the right person.', NULL, 'curiosity', 0.71, 'public', FALSE, NULL, ARRAY['self_worth', 'dating', 'trust'], 38),
  (49, 'jasmine.clark@example.com', 'I wish daydreaming about love did not make me feel foolish.', NULL, 'love', 0.79, 'public', FALSE, NULL, ARRAY['love', 'hope', 'dating'], 12),
  (50, 'jasmine.clark@example.com', 'I wish someone would send voice notes just because they thought of me.', 'I would love a connection that feels warm enough for unexpected voice notes.', 'joy', 0.74, 'public', FALSE, NULL, ARRAY['love', 'connection', 'communication'], 22),
  (51, 'jasmine.clark@example.com', 'I wish my anxiety did not rewrite every good moment.', NULL, 'anxiety', 0.89, 'public', FALSE, NULL, ARRAY['anxiety', 'mental_health', 'love'], 39),
  (52, 'ethan.turner@example.com', 'I wish optimism did not have to fight so hard for space in me.', NULL, 'joy', 0.68, 'public', FALSE, NULL, ARRAY['growth', 'hope', 'mental_health'], 11),
  (53, 'ethan.turner@example.com', 'I wish I could stop treating rest like a reward.', NULL, 'anxiety', 0.77, 'deleted', FALSE, NULL, ARRAY['stress', 'self_care', 'career'], 31),
  (54, 'ethan.turner@example.com', 'I wish someone wanted to build something gentle and real.', NULL, 'love', 0.85, 'public', FALSE, NULL, ARRAY['love', 'connection', 'commitment'], 42),
  (55, 'nora.singh@example.com', 'I wish depth was not so hard to find in fast conversations.', NULL, 'curiosity', 0.83, 'public', FALSE, NULL, ARRAY['connection', 'dating', 'growth'], 6),
  (56, 'nora.singh@example.com', 'I wish someone would meet me where the real questions live.', 'I''m looking for someone willing to meet me where the real questions begin.', 'curiosity', 0.80, 'public', FALSE, NULL, ARRAY['vulnerability', 'growth', 'connection'], 18),
  (57, 'nora.singh@example.com', 'I wish I could share my tenderness without editing it down.', NULL, 'love', 0.87, 'public', FALSE, NULL, ARRAY['love', 'vulnerability', 'self_worth'], 37),
  (58, 'leo.garcia@example.com', 'I wish I knew whether solitude is healing me or hiding me.', NULL, 'curiosity', 0.76, 'public', FALSE, NULL, ARRAY['loneliness', 'growth', 'healing'], 13),
  (59, 'leo.garcia@example.com', 'I wish the right kind of chaos still existed.', NULL, 'joy', 0.65, 'public', FALSE, NULL, ARRAY['adventure', 'joy', 'dating'], 26),
  (60, 'leo.garcia@example.com', 'I wish I could tell the difference between intuition and fear.', NULL, 'anxiety', 0.84, 'public', FALSE, NULL, ARRAY['anxiety', 'growth', 'self_trust'], 49);

INSERT INTO wishes (
  id,
  user_id,
  content,
  ai_refined_content,
  used_ai_refinement,
  emotion_label,
  emotion_score,
  embedding,
  visibility,
  is_moderated,
  moderation_flag,
  created_at,
  updated_at
)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish:' || sw.wish_no::TEXT),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(sw.email_plain)),
  sw.content,
  sw.ai_refined_content,
  (sw.ai_refined_content IS NOT NULL),
  sw.emotion_label,
  sw.emotion_score,
  seed_placeholder_embedding(sw.wish_no),
  sw.visibility,
  sw.is_moderated,
  sw.moderation_flag,
  CURRENT_TIMESTAMP - make_interval(hours => sw.hours_ago),
  CURRENT_TIMESTAMP - make_interval(hours => sw.hours_ago)
FROM seed_wishes sw
WHERE NOT EXISTS (
  SELECT 1
  FROM wishes w
  WHERE w.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish:' || sw.wish_no::TEXT)
);

INSERT INTO wish_tags (id, wish_id, tag)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish-tag:' || sw.wish_no::TEXT || ':' || tag_value.tag),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish:' || sw.wish_no::TEXT),
  tag_value.tag
FROM seed_wishes sw
CROSS JOIN LATERAL unnest(sw.tags) AS tag_value(tag)
WHERE NOT EXISTS (
  SELECT 1
  FROM wish_tags wt
  WHERE wt.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish-tag:' || sw.wish_no::TEXT || ':' || tag_value.tag)
);

CREATE TEMP TABLE seed_subscriptions (
  email_plain TEXT,
  stripe_subscription_id TEXT,
  glow_color TEXT,
  particle_style particle_style_enum,
  animation_speed animation_speed_enum
) ON COMMIT DROP;

INSERT INTO seed_subscriptions (email_plain, stripe_subscription_id, glow_color, particle_style, animation_speed)
VALUES
  ('alba.rivera@example.com', 'sub_seed_001', '#6bb7ff', 'sparkle', 'medium'),
  ('ari.kim@example.com', 'sub_seed_002', '#87c38f', 'ripple', 'slow'),
  ('priya.shah@example.com', 'sub_seed_003', '#ffb36b', 'ember', 'medium'),
  ('chloe.martin@example.com', 'sub_seed_004', '#f28fb0', 'dust', 'fast'),
  ('mateo.alvarez@example.com', 'sub_seed_005', '#c5b3ff', 'ripple', 'slow');

INSERT INTO subscriptions (
  id,
  user_id,
  plan,
  feature_flags,
  stripe_subscription_id,
  started_at,
  expires_at,
  created_at
)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:subscription:' || lower(ss.email_plain)),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(ss.email_plain)),
  'premium',
  jsonb_build_object(
    'priority_matching', TRUE,
    'unlimited_wishes', TRUE,
    'aura_custom', TRUE
  ),
  ss.stripe_subscription_id,
  CURRENT_TIMESTAMP - INTERVAL '15 days',
  CURRENT_TIMESTAMP + INTERVAL '75 days',
  CURRENT_TIMESTAMP - INTERVAL '15 days'
FROM seed_subscriptions ss
WHERE NOT EXISTS (
  SELECT 1
  FROM subscriptions s
  WHERE s.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:subscription:' || lower(ss.email_plain))
);

INSERT INTO aura_customizations (id, user_id, glow_color, particle_style, animation_speed, updated_at)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:aura:' || lower(ss.email_plain)),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(ss.email_plain)),
  ss.glow_color,
  ss.particle_style,
  ss.animation_speed,
  CURRENT_TIMESTAMP - INTERVAL '2 days'
FROM seed_subscriptions ss
WHERE NOT EXISTS (
  SELECT 1
  FROM aura_customizations ac
  WHERE ac.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:aura:' || lower(ss.email_plain))
);

CREATE TEMP TABLE seed_blocks (
  blocker_email TEXT,
  blocked_email TEXT,
  days_ago INTEGER
) ON COMMIT DROP;

INSERT INTO seed_blocks (blocker_email, blocked_email, days_ago)
VALUES
  ('zoe.bennett@example.com', 'leo.garcia@example.com', 5),
  ('marcus.reed@example.com', 'chloe.martin@example.com', 9),
  ('nora.singh@example.com', 'miles.cho@example.com', 12);

INSERT INTO blocks (id, blocker_user_id, blocked_user_id, created_at)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:block:' || lower(sb.blocker_email) || ':' || lower(sb.blocked_email)),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(sb.blocker_email)),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(sb.blocked_email)),
  CURRENT_TIMESTAMP - make_interval(days => sb.days_ago)
FROM seed_blocks sb
WHERE NOT EXISTS (
  SELECT 1
  FROM blocks b
  WHERE b.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:block:' || lower(sb.blocker_email) || ':' || lower(sb.blocked_email))
);

CREATE TEMP TABLE seed_interactions (
  interaction_no INTEGER,
  actor_email TEXT,
  wish_no INTEGER,
  type interaction_type_enum,
  hours_ago INTEGER
) ON COMMIT DROP;

INSERT INTO seed_interactions (interaction_no, actor_email, wish_no, type, hours_ago)
VALUES
  (1, 'priya.shah@example.com', 1, 'resonate', 26),
  (2, 'alba.rivera@example.com', 21, 'resonate', 25),
  (3, 'marcus.reed@example.com', 4, 'resonate', 24),
  (4, 'miles.cho@example.com', 22, 'resonate', 23),
  (5, 'sarah.nguyen@example.com', 7, 'resonate', 22),
  (6, 'lena.hart@example.com', 43, 'resonate', 21),
  (7, 'ethan.turner@example.com', 10, 'resonate', 20),
  (8, 'ari.kim@example.com', 54, 'resonate', 19),
  (9, 'mateo.alvarez@example.com', 29, 'resonate', 18),
  (10, 'noah.patel@example.com', 47, 'resonate', 17),
  (11, 'nora.singh@example.com', 16, 'resonate', 16),
  (12, 'jordan.ellis@example.com', 55, 'resonate', 15),
  (13, 'jasmine.clark@example.com', 41, 'resonate', 14),
  (14, 'dylan.foster@example.com', 49, 'resonate', 13),
  (15, 'chloe.martin@example.com', 13, 'resonate', 12),
  (16, 'maya.lopez@example.com', 32, 'reflect', 11),
  (17, 'zoe.bennett@example.com', 39, 'reflect', 10),
  (18, 'aya.nakamura@example.com', 31, 'respond', 9),
  (19, 'ethan.turner@example.com', 36, 'reflect', 8),
  (20, 'alba.rivera@example.com', 50, 'respond', 7),
  (21, 'priya.shah@example.com', 45, 'dive_deeper', 6),
  (22, 'leo.garcia@example.com', 11, 'reflect', 5),
  (23, 'noah.patel@example.com', 24, 'respond', 4),
  (24, 'sarah.nguyen@example.com', 30, 'dive_deeper', 4),
  (25, 'miles.cho@example.com', 52, 'reflect', 3),
  (26, 'marcus.reed@example.com', 6, 'respond', 3),
  (27, 'nora.singh@example.com', 18, 'dive_deeper', 2),
  (28, 'mateo.alvarez@example.com', 33, 'reflect', 2),
  (29, 'jasmine.clark@example.com', 2, 'respond', 1),
  (30, 'ari.kim@example.com', 59, 'dive_deeper', 1);

INSERT INTO interactions (id, actor_user_id, target_wish_id, type, created_at)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:interaction:' || si.interaction_no::TEXT),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(si.actor_email)),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish:' || si.wish_no::TEXT),
  si.type,
  CURRENT_TIMESTAMP - make_interval(hours => si.hours_ago)
FROM seed_interactions si
WHERE NOT EXISTS (
  SELECT 1
  FROM interactions i
  WHERE i.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:interaction:' || si.interaction_no::TEXT)
);

CREATE TEMP TABLE seed_matches (
  match_no INTEGER,
  wish_no_a INTEGER,
  wish_no_b INTEGER,
  similarity_score DOUBLE PRECISION,
  match_status match_status_enum,
  created_days_ago INTEGER,
  expires_offset_days INTEGER,
  revealed_hours_ago INTEGER
) ON COMMIT DROP;

INSERT INTO seed_matches (
  match_no,
  wish_no_a,
  wish_no_b,
  similarity_score,
  match_status,
  created_days_ago,
  expires_offset_days,
  revealed_hours_ago
)
VALUES
  (1, 1, 21, 0.93, 'opened', 3, 4, 48),
  (2, 4, 22, 0.95, 'opened', 2, 5, 30),
  (3, 7, 43, 0.89, 'opened', 6, 1, 72),
  (4, 10, 54, 0.84, 'opened', 1, 6, 10),
  (5, 29, 47, 0.81, 'opened', 5, 2, 40),
  (6, 16, 55, 0.80, 'pending', 1, 6, NULL),
  (7, 14, 32, 0.77, 'pending', 3, 4, NULL),
  (8, 37, 57, 0.83, 'rejected', 4, 3, NULL),
  (9, 41, 49, 0.74, 'expired', 10, -3, NULL),
  (10, 31, 56, 0.79, 'expired', 9, -2, NULL);

INSERT INTO matches (
  id,
  user_id_a,
  user_id_b,
  wish_id_a,
  wish_id_b,
  similarity_score,
  shared_themes,
  match_status,
  revealed_at,
  expires_at,
  created_at
)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:match:' || sm.match_no::TEXT),
  CASE
    WHEN wa.user_id::TEXT <= wb.user_id::TEXT THEN wa.user_id
    ELSE wb.user_id
  END AS user_id_a,
  CASE
    WHEN wa.user_id::TEXT <= wb.user_id::TEXT THEN wb.user_id
    ELSE wa.user_id
  END AS user_id_b,
  CASE
    WHEN wa.user_id::TEXT <= wb.user_id::TEXT THEN wa.id
    ELSE wb.id
  END AS wish_id_a,
  CASE
    WHEN wa.user_id::TEXT <= wb.user_id::TEXT THEN wb.id
    ELSE wa.id
  END AS wish_id_b,
  sm.similarity_score,
  COALESCE(ARRAY(
    SELECT shared.tag
    FROM (
      SELECT tag FROM wish_tags WHERE wish_id = wa.id
      INTERSECT
      SELECT tag FROM wish_tags WHERE wish_id = wb.id
    ) AS shared(tag)
    ORDER BY shared.tag
  ), ARRAY[]::TEXT[]),
  sm.match_status,
  CASE
    WHEN sm.revealed_hours_ago IS NULL THEN NULL
    ELSE CURRENT_TIMESTAMP - make_interval(hours => sm.revealed_hours_ago)
  END,
  CURRENT_TIMESTAMP + make_interval(days => sm.expires_offset_days),
  CURRENT_TIMESTAMP - make_interval(days => sm.created_days_ago)
FROM seed_matches sm
JOIN wishes wa ON wa.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish:' || sm.wish_no_a::TEXT)
JOIN wishes wb ON wb.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish:' || sm.wish_no_b::TEXT)
WHERE NOT EXISTS (
  SELECT 1
  FROM matches m
  WHERE m.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:match:' || sm.match_no::TEXT)
);

CREATE TEMP TABLE seed_conversations (
  conversation_no INTEGER,
  match_no INTEGER,
  identity_revealed_a BOOLEAN,
  identity_revealed_b BOOLEAN,
  is_active BOOLEAN,
  created_hours_ago INTEGER
) ON COMMIT DROP;

INSERT INTO seed_conversations (
  conversation_no,
  match_no,
  identity_revealed_a,
  identity_revealed_b,
  is_active,
  created_hours_ago
)
VALUES
  (1, 1, FALSE, FALSE, TRUE, 46),
  (2, 2, FALSE, FALSE, TRUE, 28),
  (3, 3, TRUE, FALSE, TRUE, 70),
  (4, 4, FALSE, FALSE, TRUE, 9),
  (5, 5, TRUE, TRUE, TRUE, 38);

INSERT INTO conversations (
  id,
  match_id,
  identity_revealed_a,
  identity_revealed_b,
  is_active,
  created_at
)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:conversation:' || sc.conversation_no::TEXT),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:match:' || sc.match_no::TEXT),
  sc.identity_revealed_a,
  sc.identity_revealed_b,
  sc.is_active,
  CURRENT_TIMESTAMP - make_interval(hours => sc.created_hours_ago)
FROM seed_conversations sc
WHERE NOT EXISTS (
  SELECT 1
  FROM conversations c
  WHERE c.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:conversation:' || sc.conversation_no::TEXT)
);

CREATE TEMP TABLE seed_messages (
  message_no INTEGER,
  conversation_no INTEGER,
  sender_email TEXT,
  content TEXT,
  ai_suggested BOOLEAN,
  is_deleted BOOLEAN,
  hours_ago INTEGER
) ON COMMIT DROP;

INSERT INTO seed_messages (
  message_no,
  conversation_no,
  sender_email,
  content,
  ai_suggested,
  is_deleted,
  hours_ago
)
VALUES
  (1, 1, 'alba.rivera@example.com', 'Your kitchen-dance wish made me smile.', FALSE, FALSE, 26),
  (2, 1, 'priya.shah@example.com', 'Late-night walks and kitchen dancing sound compatible.', FALSE, FALSE, 25),
  (3, 1, 'alba.rivera@example.com', 'That feels like a very generous read.', FALSE, FALSE, 24),
  (4, 1, 'priya.shah@example.com', 'Maybe I am just drawn to gentle rituals.', FALSE, FALSE, 23),
  (5, 1, 'alba.rivera@example.com', 'Same. They make closeness feel steady.', FALSE, FALSE, 22),
  (6, 2, 'miles.cho@example.com', 'The overthinking line felt painfully accurate.', FALSE, FALSE, 18),
  (7, 2, 'marcus.reed@example.com', 'Midnight brain club?', FALSE, FALSE, 17),
  (8, 2, 'miles.cho@example.com', 'Unfortunately yes.', FALSE, FALSE, 16),
  (9, 2, 'marcus.reed@example.com', 'At least someone else gets the static.', FALSE, FALSE, 15),
  (10, 2, 'miles.cho@example.com', 'Slow replies, deep thoughts, no pressure sounds nice.', TRUE, FALSE, 14),
  (11, 3, 'lena.hart@example.com', 'Your line about healing in the middle stayed with me.', FALSE, FALSE, 70),
  (12, 3, 'sarah.nguyen@example.com', 'I almost deleted it. Thank you for saying that.', FALSE, FALSE, 69),
  (13, 3, 'lena.hart@example.com', 'Invisible grief deserves witnesses.', FALSE, FALSE, 68),
  (14, 3, 'sarah.nguyen@example.com', 'That sentence hit hard in a good way.', FALSE, TRUE, 67),
  (15, 3, 'lena.hart@example.com', 'Then maybe this match did exactly what it needed to.', FALSE, FALSE, 66),
  (16, 4, 'ari.kim@example.com', 'Gentle and real is exactly what I am hoping for.', FALSE, FALSE, 9),
  (17, 4, 'ethan.turner@example.com', 'Routines together sounded unexpectedly romantic to me.', FALSE, FALSE, 8),
  (18, 4, 'ari.kim@example.com', 'Consistency is underrated.', FALSE, FALSE, 7),
  (19, 4, 'ethan.turner@example.com', 'Agreed. Sparks are easy. Showing up is the art.', FALSE, FALSE, 6),
  (20, 4, 'ari.kim@example.com', 'That might be the most attractive sentence I have read today.', TRUE, FALSE, 5),
  (21, 5, 'noah.patel@example.com', 'Silence with understanding sounds rare.', FALSE, FALSE, 40),
  (22, 5, 'mateo.alvarez@example.com', 'So does consistency without performance.', FALSE, FALSE, 39),
  (23, 5, 'noah.patel@example.com', 'Maybe we are both tired of noise.', FALSE, FALSE, 38),
  (24, 5, 'mateo.alvarez@example.com', 'That feels true.', FALSE, FALSE, 37),
  (25, 5, 'noah.patel@example.com', 'I would rather build trust slowly than perform chemistry.', FALSE, FALSE, 36);

INSERT INTO messages (
  id,
  conversation_id,
  sender_user_id,
  content,
  ai_suggested,
  is_deleted,
  sent_at
)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:message:' || sm.message_no::TEXT),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:conversation:' || sm.conversation_no::TEXT),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(sm.sender_email)),
  sm.content,
  sm.ai_suggested,
  sm.is_deleted,
  CURRENT_TIMESTAMP - make_interval(hours => sm.hours_ago)
FROM seed_messages sm
WHERE NOT EXISTS (
  SELECT 1
  FROM messages m
  WHERE m.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:message:' || sm.message_no::TEXT)
);

INSERT INTO notifications (
  id,
  user_id,
  type,
  title,
  body,
  is_read,
  related_entity_id,
  created_at
)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:notification:' || notification_seed.notification_no::TEXT),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(notification_seed.email_plain)),
  notification_seed.type,
  notification_seed.title,
  notification_seed.body,
  notification_seed.is_read,
  CASE notification_seed.related_kind
    WHEN 'match' THEN uuid_generate_v5(uuid_ns_url(), 'wishing-well:match:' || notification_seed.related_no::TEXT)
    WHEN 'message' THEN uuid_generate_v5(uuid_ns_url(), 'wishing-well:message:' || notification_seed.related_no::TEXT)
    WHEN 'wish' THEN uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish:' || notification_seed.related_no::TEXT)
    ELSE NULL
  END,
  CURRENT_TIMESTAMP - make_interval(hours => notification_seed.hours_ago)
FROM (
  VALUES
    (1, 'alba.rivera@example.com', 'system'::notification_type_enum, 'Welcome to Wishing Well', 'Your anonymous profile is live and ready for gentle matching.', FALSE, NULL::TEXT, NULL::INTEGER, 48),
    (2, 'ari.kim@example.com', 'system'::notification_type_enum, 'Premium aura unlocked', 'Your aura customization is active with ripple motion and a grounded glow.', TRUE, NULL::TEXT, NULL::INTEGER, 24),
    (3, 'priya.shah@example.com', 'reveal_request'::notification_type_enum, 'A conversation is deepening', 'One of your matches is ready for a gentle reveal step whenever you are.', FALSE, 'match'::TEXT, 1, 12),
    (4, 'noah.patel@example.com', 'message'::notification_type_enum, 'A thoughtful reply arrived', 'Someone responded in a way that feels worth returning to.', FALSE, 'message'::TEXT, 24, 6),
    (5, 'chloe.martin@example.com', 'system'::notification_type_enum, 'Weekly summary ready', 'Your emotional pattern snapshot has been refreshed with new themes.', FALSE, NULL::TEXT, NULL::INTEGER, 3)
) AS notification_seed(notification_no, email_plain, type, title, body, is_read, related_kind, related_no, hours_ago)
WHERE NOT EXISTS (
  SELECT 1
  FROM notifications n
  WHERE n.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:notification:' || notification_seed.notification_no::TEXT)
);

INSERT INTO reports (
  id,
  reporter_user_id,
  reported_user_id,
  reported_wish_id,
  reported_message_id,
  reason,
  status,
  created_at
)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:report:' || report_seed.report_no::TEXT),
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(report_seed.reporter_email)),
  CASE
    WHEN report_seed.reported_email IS NULL THEN NULL
    ELSE uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(report_seed.reported_email))
  END,
  CASE
    WHEN report_seed.reported_wish_no IS NULL THEN NULL
    ELSE uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish:' || report_seed.reported_wish_no::TEXT)
  END,
  CASE
    WHEN report_seed.reported_message_no IS NULL THEN NULL
    ELSE uuid_generate_v5(uuid_ns_url(), 'wishing-well:message:' || report_seed.reported_message_no::TEXT)
  END,
  report_seed.reason,
  report_seed.status,
  CURRENT_TIMESTAMP - make_interval(hours => report_seed.hours_ago)
FROM (
  VALUES
    (1, 'leo.garcia@example.com', NULL::TEXT, 34, NULL::INTEGER, 'This wish sounded like someone might need a wellbeing check.', 'resolved'::report_status_enum, 20),
    (2, 'chloe.martin@example.com', NULL::TEXT, NULL::INTEGER, 14, 'This message felt emotionally heavy in a way that needed review.', 'open'::report_status_enum, 18),
    (3, 'miles.cho@example.com', 'leo.garcia@example.com', NULL::INTEGER, NULL::INTEGER, 'Profile behavior felt inconsistent and evasive after repeated contact.', 'dismissed'::report_status_enum, 10)
) AS report_seed(report_no, reporter_email, reported_email, reported_wish_no, reported_message_no, reason, status, hours_ago)
WHERE NOT EXISTS (
  SELECT 1
  FROM reports r
  WHERE r.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:report:' || report_seed.report_no::TEXT)
);

INSERT INTO moderation_logs (
  id,
  wish_id,
  message_id,
  triggered_by,
  reason,
  action_taken,
  reviewed_by_admin,
  created_at
)
SELECT
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:moderation:' || log_seed.log_no::TEXT),
  CASE
    WHEN log_seed.wish_no IS NULL THEN NULL
    ELSE uuid_generate_v5(uuid_ns_url(), 'wishing-well:wish:' || log_seed.wish_no::TEXT)
  END,
  CASE
    WHEN log_seed.message_no IS NULL THEN NULL
    ELSE uuid_generate_v5(uuid_ns_url(), 'wishing-well:message:' || log_seed.message_no::TEXT)
  END,
  log_seed.triggered_by,
  log_seed.reason,
  log_seed.action_taken,
  log_seed.reviewed_by_admin,
  CURRENT_TIMESTAMP - make_interval(hours => log_seed.hours_ago)
FROM (
  VALUES
    (1, 34, NULL::INTEGER, 'ai'::moderation_trigger_enum, 'Wellbeing escalation keywords detected for manual review.', 'reviewed'::moderation_action_enum, TRUE, 19),
    (2, NULL::INTEGER, 14, 'user_report'::moderation_trigger_enum, 'Recipient reported the tone as overwhelming during an active grief conversation.', 'removed'::moderation_action_enum, TRUE, 17),
    (3, 59, NULL::INTEGER, 'admin'::moderation_trigger_enum, 'Context reviewed after a flag and cleared for continued visibility.', 'cleared'::moderation_action_enum, TRUE, 8)
) AS log_seed(log_no, wish_no, message_no, triggered_by, reason, action_taken, reviewed_by_admin, hours_ago)
WHERE NOT EXISTS (
  SELECT 1
  FROM moderation_logs ml
  WHERE ml.id = uuid_generate_v5(uuid_ns_url(), 'wishing-well:moderation:' || log_seed.log_no::TEXT)
);

SELECT update_emotional_patterns(
  uuid_generate_v5(uuid_ns_url(), 'wishing-well:user:' || lower(su.email_plain))
)
FROM seed_users su;

DROP FUNCTION IF EXISTS seed_placeholder_embedding(INTEGER);

COMMIT;
