BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type_enum') THEN
    BEGIN
      ALTER TYPE notification_type_enum ADD VALUE IF NOT EXISTS 'wish_reply';
    EXCEPTION
      WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      ALTER TYPE notification_type_enum ADD VALUE IF NOT EXISTS 'wish_reply_reply';
    EXCEPTION
      WHEN duplicate_object THEN NULL;
    END;
  END IF;
END
$$;

COMMIT;
