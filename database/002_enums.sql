BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_intent_enum') THEN
    CREATE TYPE user_intent_enum AS ENUM ('connect', 'express', 'explore');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wish_emotion_enum') THEN
    CREATE TYPE wish_emotion_enum AS ENUM (
      'sadness',
      'love',
      'curiosity',
      'anxiety',
      'joy',
      'anger',
      'neutral'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wish_visibility_enum') THEN
    CREATE TYPE wish_visibility_enum AS ENUM ('public', 'archived', 'deleted');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'interaction_type_enum') THEN
    CREATE TYPE interaction_type_enum AS ENUM ('resonate', 'reflect', 'respond', 'dive_deeper');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'match_status_enum') THEN
    CREATE TYPE match_status_enum AS ENUM ('pending', 'opened', 'rejected', 'expired');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'moderation_trigger_enum') THEN
    CREATE TYPE moderation_trigger_enum AS ENUM ('ai', 'user_report', 'admin');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'moderation_action_enum') THEN
    CREATE TYPE moderation_action_enum AS ENUM ('warned', 'removed', 'reviewed', 'cleared');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_status_enum') THEN
    CREATE TYPE report_status_enum AS ENUM ('open', 'resolved', 'dismissed');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type_enum') THEN
    CREATE TYPE notification_type_enum AS ENUM (
      'resonance',
      'new_match',
      'message',
      'reveal_request',
      'system'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_plan_enum') THEN
    CREATE TYPE subscription_plan_enum AS ENUM ('free', 'premium');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'particle_style_enum') THEN
    CREATE TYPE particle_style_enum AS ENUM ('dust', 'sparkle', 'ripple', 'ember');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'animation_speed_enum') THEN
    CREATE TYPE animation_speed_enum AS ENUM ('slow', 'medium', 'fast');
  END IF;
END
$$;

COMMIT;
